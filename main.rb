require 'rubygems'
require 'bundler'
require 'net/http'
require 'zip'

Bundler.require( :default )

Dir.glob( './classes/*.rb' ) { | file | require( file ) }

t = Transferer.new( 'http://bitly.com/nuvi-plz', './news_xml/', 'NEWS_XML' )
t.scrape_zip_links
t.download_and_unpack( t.zips.slice( 0, 1 ) )
t.load_to_redis
