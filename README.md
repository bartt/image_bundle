=ImageBundle

ImageBundleHelper adds view helper +image_bundle+. A helper which
bundles individual local images into a single CSS sprite thereby
reducing the number of HTTP requests needed to render the page.

{Yahoo's Exceptional Performance
team}[http://developer.yahoo.com/performance/] found that the number
of HTTP requests has the biggest impact on page rendering speed. You
can inspect your site's performance with the excellent Firefox add-on
{YSlow}[http://developer.yahoo.com/yslow/].

== Usage

Use ImageBundle to automatically replace individual local images into
CSS sprites.

== Demo

A demo of ImageBundle is available at http://thecodemill.biz/image_bundle/.

== Note on <tt>image_tag</tt> helper

Rails' <tt>image_tag</tt> helper adds a query parameter to the image URL to
'bust caches'. It ads either the <tt>RAILS_ASSET_ID</tt> environment variable
or the image's modification time.  This is the *wrong* thing to
do. Caches should be managed through the use of HTTP headers such as
Cache-Control, Last-Modified, Expires and of course the HTTP response
code.  Adding the modification time is the same as using as using
ETags in apache or IIS, see
http://developer.yahoo.com/performance/rules.html#etags for an
explanation why it is better to avoid using ETags in favor of proper
Expires headers.

This plugin doesn't accept image URLS that include query parameters as
they are either dynamically generated and shouldn't be part of a
sprite or they promote a bad practice.

If you like to use the <tt>image_tag</tt> helper I recommend you a) configure
the webserver of you static content to return proper headers and b) to
overwrite <tt>ActionView::Helpers::AssetTagsHelper#rewrite_asset_path!</tt>
like so:

  module ActionView
    module Helpers
      module AssetTagHelper
        def rewrite_asset_path!(source)
        end
      end
    end
  end

Create a file <tt>lib/asset_tag_helper.rb</tt> and load it at the end of your
<tt>config/environment.rb</tt> file like so:

  require File.join(File.dirname(__FILE__), '../lib/asset_tag_helper')

== License & Author

:include: LICENSE