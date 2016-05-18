class Transferer
  
  attr_accessor :destination_folder, :destination_list, :folder_uri, :origin_url, :zips
  
  def initialize( origin_url, destination_folder, destination_list )
    @origin_url = Transferer.resolve_url( origin_url )
    @destination_folder = destination_folder[ -1 ] == '/' ? destination_folder : destination_folder + '/'
    @destination_list = destination_list
  end
  
  def self.resolve_url( url )
    uri = URI.parse( URI.encode( url ) )
    resp = Net::HTTP.get_response( uri )
    
    if resp.kind_of?( Net::HTTPRedirection )
      if !resp.header[ 'location' ]
        url = Nokogiri::HTML( Net::HTTP.get( uri ) ).css( 'a' )[ 0 ].attr( 'href' )
      else
        url = resp.header[ 'location' ]
      end
      
      url = resolve_url( url )
    end
    
    url
  end
  
  def download_and_unpack( zips )
    uri = URI.parse( URI.encode( self.origin_url ) )
    
    Net::HTTP.start( uri.host, uri.port ) do | http |
      FileUtils.mkdir( destination_folder ) if !Dir.exists?( destination_folder )
      
      zips.each do | zip |
        puts( 'Downloading and extracting ' + zip + '...' )
        
        File.delete( destination_folder + zip ) if File.exists?( destination_folder + zip )
        
        File.open( destination_folder + zip, 'wb' ) do | file |
          http.get( URI.parse( URI.encode( self.origin_url + zip ) ) ) do | str |
            file.write( str )
          end
        end
                
        Zip::File.open( destination_folder + zip ) do | zip_file |
          zip_file.each do | entry |
            File.delete( destination_folder + entry.name ) if File.exists?( destination_folder + entry.name )
            entry.extract( destination_folder + entry.name )
          end
        end
        
        File.delete( destination_folder + zip ) if File.exists?( destination_folder + zip )
      end
    end
  end
  
  def load_to_redis
    redis = Redis.new
    
    puts( 'Starting entries in ' + destination_list + ': ' + redis.llen( destination_list ).to_s )
    
    Dir.glob( destination_folder + '*.xml' ) do | xml_file |
      xml = File.open( xml_file ).read
      redis.lrem( destination_list, 0, xml )
      redis.lpush( destination_list, xml )
    end
    
    puts( 'Finishing entries in ' + destination_list + ': ' + redis.llen( destination_list ).to_s )
  end
  
  def scrape_zip_links
    page = Net::HTTP.get( URI.parse( self.origin_url ) )
    
    self.zips = Nokogiri::HTML( page ).css( 'a' ).map do | link |
      if ( href = link.attr( 'href' ) ) && href.match( /zip$/ )
        href
      end
    end.compact
  end
end
