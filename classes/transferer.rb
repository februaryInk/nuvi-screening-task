class Transferer
  
  attr_accessor :destination_folder, :destination_list, :origin_url, :zips
  
  # CLASS METHODS
  
  # follow url redirects and return the final url.
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
  
  # INSTANCE METHODS
  
  def initialize( origin_url, destination_folder, destination_list )
    @origin_url = Transferer.resolve_url( origin_url )
    @destination_folder = destination_folder[ -1 ] == '/' ? destination_folder : destination_folder + '/'
    @destination_list = destination_list
    @zips = [  ]
  end
  
  # download and unpack one zip.
  def download_and_unpack( http, zip )
    uri = URI.parse( URI.encode( self.origin_url + zip ) )
    zip_destination = self.destination_folder + zip
    
    if Net::HTTP.get_response( uri ).kind_of?( Net::HTTPSuccess )
      puts 'Downloading and extracting ' + zip + '...'
      
      begin
        File.delete( zip_destination ) if File.exists?( zip_destination )
        
        File.open( zip_destination, 'wb' ) do | file |
          http.get( uri ) do | str |
            file.write( str )
          end
        end
                
        Zip::File.open( zip_destination ) do | zip_file |
          zip_file.each do | entry |
            entry_destination = self.destination_folder + entry.name
            File.delete( entry_destination ) if File.exists?( entry_destination )
            entry.extract( entry_destination )
          end
        end
      rescue StandardError => e
        puts( e )
      end
    else
      puts 'File ' + zip + ' could not be reached.'
    end
    
    File.delete( zip_destination ) if File.exists?( zip_destination )
  end
  
  # iterate over the zips and download and unpack each one. if these zips
  # never change, could keep a list of those already processed in Redis...
  def download_and_unpack_many( zips )
    uri = URI.parse( URI.encode( self.origin_url ) )
    
    Net::HTTP.start( uri.host, uri.port ) do | http |
      FileUtils.mkdir( self.destination_folder ) if !Dir.exists?( self.destination_folder )
      
      zips.each do | zip |
        self.download_and_unpack( http, zip )
      end
    end
  end
  
  # store the contents of the xml files in Redis. delete the xml files after.
  def load_to_redis
    redis = Redis.new
    
    puts 'Starting entries in ' + destination_list + ': ' + redis.llen( destination_list ).to_s
    
    Dir.glob( destination_folder + '*.xml' ) do | xml_file |
      xml = File.open( xml_file ).read
      redis.lrem( destination_list, 0, xml )
      redis.lpush( destination_list, xml )
      
      File.delete( xml_file )
    end
    
    puts 'Finishing entries in ' + destination_list + ': ' + redis.llen( destination_list ).to_s
    FileUtils.rm_rf( self.destination_folder ) if Dir.glob( self.destination_folder ).empty?
  end
  
  # find the zips contained in the http folder.
  def scrape_zip_links
    page = Net::HTTP.get( URI.parse( self.origin_url ) )
    
    self.zips = Nokogiri::HTML( page ).css( 'a' ).map do | link |
      if ( href = link.attr( 'href' ) ) && href.match( /zip$/ )
        href
      end
    end.compact.uniq
  end
end
