require( 'rubygems' )
require( 'bundler' )

require( 'fileutils' )
require( 'net/http' )
require( 'zip' )

Bundler.require( :default )

Dir.glob( './classes/*.rb' ) { | file | require( file ) }

t = Transferer.new( 'http://bitly.com/nuvi-plz', './news_xml/', 'NEWS_XML' )
t.scrape_zip_links
# just try a couple of the zips. all of them would take a while.
t.download_and_unpack_many( t.zips.slice( 0, 1 ) )
t.load_to_redis
