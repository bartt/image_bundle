module ImageBundleHelper
  require 'rubygems'
  require 'RMagick'
  require 'digest/md5'

  class Image
    attr_accessor :path, :file, :height, :width, :x_pos
  end

  def image_bundle(css_class = nil, sprite_type = :png, *args, &block) 
    # Bind buffer to the ERB output buffer of the templates.
    buffer = eval("_erbout", block.binding)

    # Mark the current position in the buffer
    pos = buffer.length

    # Render the block contained within the image_bundle tag. The
    # rendered output is appended to buffer.
    block.call(*args)

    # Extract the output produced by the block.
    block_output = buffer[pos..-1]
    buffer[pos..-1] = ''

    # Replace the img tags in the output with links to clear.gif and
    # styling to use the master image created from the individual
    # images.
    images = Hash.new
    re = (css_class == nil) ? /(<img\s*)([^>]*?)(\s*\/?>)/im : /(<img\s*)([^>]*?class\s*=\s*["']?[^"']*?#{css_class}[^"']*?["']?[^>]*?)(\s*\/?>)/im
    block_rewrite = ''
    while pos = (block_output =~ re) do

      # Store match data for later reference.
      img_match = $~.to_s
      img_tag = $1
      attributes = $2
      img_closing_tag = $3

      # Remember where to continue searching from in the next
      # iteration.
      continue_pos = pos+img_match.length

      # Write out the content before the start of the tag 
      block_rewrite << block_output[0..pos-1]
      if img_match =~ /src\=["']?https?:\/\//i then
        block_rewrite << img_match
      else

        # Write out the opening portion of the image tag (<img).
        block_rewrite << img_tag

        # Process all attributes of the img tag.
        height_given = width_given = nil
        classes = ''
        ping = ::ImageBundleHelper::Image.new
        while pos = (attributes =~ /([^ =]+?)\s*=\s*["']?([^"']*?)["']/im) do
          attribute = $1
          value = $2
          attr_continue_pos = pos+$~.to_s.length
          case attribute
          when 'src' 
            ping.path = value
            # Read only the image's meta data not its image content.
            ping.file = "#{RAILS_ROOT}/public#{ping.path}"
            image = ::Magick::Image.ping(ping.file)[0]
            ping.height = image.rows
            ping.width = image.columns
            block_rewrite << "#{attribute}=\"/images/clear.gif\" "
          when 'height'
            height_given = value.to_i
          when 'width'
            width_given = value.to_i
          when 'class'

            # Prepend a space for later concatenation with bndl class.
            classes = " #{value}"
          else

            # Pass through all other attributes
            block_rewrite << "#{attribute}=\"#{value}\" "
          end
          attributes = attributes[attr_continue_pos..-1]
        end

        # Calculate the height and width of the image based on the
        # specified height/width and the source file's height and
        # width. Scaling needs to happen when the sprite is created
        if height_given == nil then
          if width_given != nil then
            ping.height = (ping.height * (width_given.to_f / ping.width.to_f)).to_i
            ping.width = width_given
          end
        else
          if width_given == nil then
            ping.width = (ping.width * (height_given.to_f / ping.height.to_f)).to_i
            ping.height = height_given
          else
            ping.width = width_given
            ping.height = height_given
          end
        end

        # Only add unique images and height/width combinations to the hash.
        key = "bndl#{::Digest::MD5.hexdigest("#{ping.path}:#{ping.height}:#{ping.width}").hash}"
        images[key] ||= ping
        block_rewrite << "class =\"#{key}#{classes}\" "
        block_rewrite << "height=\"#{ping.height}\" "
        block_rewrite << "width=\"#{ping.width}\" "
        block_rewrite << img_closing_tag
      end
      block_output = block_output[continue_pos..-1]
    end

    # Create a sprite when there are source files and if it doesn't
    # already exists.
    if images.length > 0 then
      sprite_path = "/sprites/" + ::Digest::MD5.hexdigest(images.keys.inject do |concat_names, key| concat_names + '|' + key end) + ".#{sprite_type}"
      sprite_file = "#{RAILS_ROOT}/public#{sprite_path}"
      if !File.exists?(sprite_file) then

        # Stack scaled source images left to right.
        sprite = images.values.inject(::Magick::ImageList.new) do |image_list, ping|
          image_list << ::Magick::ImageList.new(ping.file)[0].scale(ping.width, ping.height)
        end.append(false)
        sprite.write(sprite_file)
      end

      # While not valid XHTML, browsers do support style tags inside a
      # body tag.
      current_y = 0
      bundle_styles = "\n<style type=\"text/css\">\n"
      bundle_styles << images.keys.inject('') do |styles, key| 
        images[key].x_pos = current_y
        current_y += images[key].width
        styles + ".#{key} {\n	background-image:url(#{sprite_path});\n	background-position: -#{images[key].x_pos}px 0px;\n}\n"
      end
      bundle_styles << "</style>\n"
    end

    # Write the remaining block output that follows the last img tag.
    block_rewrite << block_output
    buffer << block_rewrite if block_rewrite
    return bundle_styles if bundle_styles
  end
  
end
