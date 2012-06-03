# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "google_drive/util"
require "google_drive/error"
require "google_drive/spreadsheet"


module GoogleDrive

    # Use GoogleDrive::Session#root_collection, GoogleDrive::Collection#subcollections,
    # or GoogleDrive::Session#collection_by_url to get GoogleDrive::Collection object.
    class Collection < GoogleDrive::File

        include(Util)
        
        #:nodoc:
        ROOT_URL = "https://docs.google.com/feeds/default/private/full/folder%3Aroot"

        alias collection_feed_url document_feed_url
        
        # Title of the collection.
        #
        # Set <tt>params[:reload]</tt> to true to force reloading the title.
        def title(params = {})
          if self.document_feed_url == ROOT_URL
            # The root collection doesn't have document feed.
            return nil
          else
            return super
          end
        end
        
        # Adds the given GoogleDrive::File to the collection.
        def add(file)
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          xml = <<-"EOS"
            <entry xmlns="http://www.w3.org/2005/Atom">
              <id>#{h(file.document_feed_url)}</id>
            </entry>
          EOS
          @session.request(
              :post, contents_url(), :data => xml, :header => header, :auth => :writely)
          return nil
        end

        # Returns all the files (including spreadsheets, documents, subcollections) in the collection.
        #
        # You can specify query parameters described at
        # https://developers.google.com/google-apps/documents-list/#getting_a_list_of_documents_and_files
        #
        # e.g.
        #
        #   # Gets all the files in collection, including subcollections.
        #   collection.files
        #   
        #   # Gets only files with title "hoge".
        #   collection.files("title" => "hoge", "title-exact" => "true")
        def files(params = {})
          return files_with_type(nil, params)
        end

        alias contents files

        # Returns all the spreadsheets in the collection.
        def spreadsheets(params = {})
          return files_with_type("spreadsheet", params)
        end
        
        # Returns all the Google Docs documents in the collection.
        def documents(params = {})
          return files_with_type("document", params)
        end
        
        # Returns all its subcollections.
        def subcollections(params = {})
          return files_with_type("folder", params)
        end
        
        # Returns its subcollection whose title exactly matches +title+ as GoogleDrive::Collection.
        # Returns nil if not found. If multiple collections with the +title+ are found, returns
        # one of them.
        def subcollection_by_title(title)
          return subcollections("title" => title, "title-exact" => "true")[0]
        end
        
        # TODO Add other operations.
        
      private
        
        def files_with_type(type, params = {})
          contents_url = contents_url()
          contents_url = concat_url(contents_url, "/-/#{type}") if type
          contents_url = concat_url(contents_url, "?" + encode_query(params))
          header = {"GData-Version" => "3.0", "Content-Type" => "application/atom+xml"}
          doc = @session.request(:get, contents_url, :header => header, :auth => :writely)
          return doc.css("feed > entry").map(){ |e| @session.entry_element_to_file(e) }
        end
        
        def contents_url
          if self.document_feed_url == ROOT_URL
            # The root collection doesn't have document feed.
            return concat_url(ROOT_URL, "/contents")
          else
            return self.document_feed_entry.css(
                "content[type='application/atom+xml;type=feed']")[0]["src"]
          end
        end
        
    end
    
end
