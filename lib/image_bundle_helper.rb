# ImageBundleHelper adds view helper +image_bundle+. A helper which
# bundles individual <strong>local images</strong> into a single CSS
# sprite thereby reducing the number of HTTP requests needed to render
# the page.
# 
# {Yahoo's Exceptional Performance
# team}[http://developer.yahoo.com/performance/] found that the number
# of HTTP requests has the biggest impact on page rendering speed. You
# can inspect your site's performance with the excellent Firefox
# add-on {YSlow}[http://developer.yahoo.com/yslow/].

module ImageBundleHelper
  require 'rubygems'
  require 'RMagick'
  require 'digest/md5'

  SPRITE_BASE_DIR = ENV['IMAGE_BUNDLE_SPRITE_BASE_DIR'] || 'sprites' if !defined?(SPRITE_BASE_DIR)

  class Image #:nodoc:
    attr_accessor :path, :file, :height, :width, :x_pos
  end

  # === +image_bundle+ takes 3 optional parameters:
  #
  # <tt>css_class</tt>::
  #     When provided <tt>css_class</tt> restricts the bundling of
  #     images to <tt><img></tt> tags of class <tt>css_class</tt>.
  #
  # <tt>sprite_type</tt>::
  #    By default +image_bundle+ generates a PNG master image. Set
  #    sprite_type to the image type you'd like to use instead. E.g. GIF
  #    or JPEG. Any type supported by
  #    {ImageMagick}[http://www.imagemagick.org/] can be generated. All
  #    images being bundled will be converted to <tt>sprite_type</tt>.
  #
  # <tt>replacement_image</tt>::
  #    By default +image_bundle+ replaces the +src+ of bundled images
  #    with <tt>/images/clear.gif</tt>. A 1x1 transparant image is
  #    included with the +image_bundle+ plugin. You'll find it in the
  #    +images+ directory of the plugin. Provide
  #    <tt>replacement_image</tt> if you prefer to use an image of
  #    different name.
  # 
  # === +image_bundle+ does 4 things:
  # 1. It creates a master image of all bundled images, if it doesn't already exist. 
  # 1. It rewrites the <tt><img></tt> tags of all images included
  #    in the bundle to use <tt>replacement_image</tt> instead.
  # 1. Each included <tt><img></tt> gets a new class <em>added</em> to the
  #    image's +class+ attribute.  The new class name is unique to the
  #    image's size and content. 
  # 1. +image_bundle+ creates matching CSS rules to display the portion
  #    of the master image equivalent to the <tt><img></tt> tags'
  #    original image.  The CSS rules are returned as a string so that
  #    they can be assigned to a variable that can be passed on to the
  #    view's layout for inclusion in the page's HTML header.
  #
  # === +image_bundle+ uses 1 environment variable:
  #
  # By default +image_bundle+ creates sprites in a directory called
  # +sprites+. +image_bundle+ doesn't use +images+ in order to
  # eliminate the potential of overwriting your images. Create
  # +sprites+ in your +public+ directory before using
  # +image_bundle+. 
  # 
  # If you prefer to use a different directory set
  # <tt>ENV['IMAGE_BUNDLE_SPRITE_BASE_DIR']</tt> in your Rails
  # environment. IMAGE_BUNDLE_SPRITE_BASE_DIR is relative to your
  # =public= directory.
  # 
  # === Example usages
  #
  # Bundle all images included within +image_bundle+'s block. Assign the
  # return value to a variable that is used in the layout of this page.
  # 
  # <% @header_includes = @header_includes.to_s + image_bundle do %>
  #   <p>+image_bundle+ can wrap any kind of content: HTML, JS, etc.</p>
  #   <img src="/images/auflag.gif"/></br>
  #   <p>Bundled images don't need to be adjacent to one another either.</p>
  #   <img src="/images/nlflag.gif"/></br>
  #   <img src="/images/frflag.gif"/></br>
  # <% end %>
  #
  # Bundle only images of class <tt>:bundle</tt>. +image_bundle+ scales resized
  # images accordingly. It calculates the 2nd dimension if only one
  # dimension is given. Bundled images don't have to be of the same size
  # either. In this case the CSS rules are included inline after the
  # +image_bundle+ block. Avoid this when possible as it isn't valid
  # HTML and causes your browser having to re-layout the page when it
  # encounters these CSS rules mid page.
  #
  # <% @sprite_css = image_bundle(:bundle) do %>
  #   <p>
  #     Some static text with <strong>HTML</strong> <em>markup</em>.<br/>
  #     Plus a dynamic date: <%= Time.now %><br/>
  #     And an 16x16 <img alt="favicon" class="bundle" src="/favicon.ico" height="16" width="16"/><br/>
  #     A 6x? <img alt="favicon" class="bundle" src="/favicon.ico" height="6"/><br/>
  #     A ?x6 <img alt="favicon" class="bundle" src="/favicon.ico" width="6"/><br/>
  #     An ?x? <img alt="favicon" class="bundle" src="/images/rails.png"/><br/>
  #     A 6x16 <img alt="favicon" src="/favicon.ico" height="6" width="16"/> not of class bundle<br/>
  #     My 160x16 multi line example <img alt="favicon" class="bundle" src="/favicon.ico"
  #     height="160"
  #     width="16"/><br/>
  #     Single quote ?x? <img alt="favicon" class='bundle' src="/favicon.ico"/><br/>
  #     Class 'some bundle' ?x? <img alt="favicon" class='some bundle' src="/favicon.ico"/><br/>
  #     Src before class ?x160 <img alt="favicon" src="/favicon.ico" class='bundle' width="160"/><br/>
  #     Src before class 'some bundle' ?x? <img alt="favicon" src="/favicon.ico" class='some bundle'/><br/>
  #     Src = and id ?x? <img alt="favicon" src="/favicon.ico" id="bla" class = 'some bundle'/><br/>
  #     Casper ?x? <img alt="favicon" class="bundle" src="/images/casper-1st-birthday.jpg"/><br/>
  #   </p>
  #   <p>
  #     Some additional text.
  #   </p>
  # <% end %>
  # 
  # <%= @sprite_css %>

  def image_bundle(css_class = nil, sprite_type = :png, replacement_image = '/images/clear.gif', *args, &block) 
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
            block_rewrite << "#{attribute}=\"#{replacement_image}\" "
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
      sprite_path = '/' + SPRITE_BASE_DIR + '/' + ::Digest::MD5.hexdigest(images.keys.inject do |concat_names, key| concat_names + '|' + key end) + ".#{sprite_type}"
      sprite_file = "#{RAILS_ROOT}/public/#{sprite_path}"
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
    return bundle_styles ||= ''
  end
  
end
