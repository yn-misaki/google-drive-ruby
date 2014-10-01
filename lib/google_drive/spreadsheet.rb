# Author: Hiroshi Ichikawa <http://gimite.net/>
# The license of this source is "New BSD Licence"

require "time"

require "google_drive/util"
require "google_drive/error"
require "google_drive/worksheet"
require "google_drive/table"
require "google_drive/acl"
require "google_drive/file"


module GoogleDrive
    
    # A spreadsheet.
    #
    # Use methods in GoogleDrive::Session to get GoogleDrive::Spreadsheet object.
    class Spreadsheet < GoogleDrive::File

        include(Util)
        
        SUPPORTED_EXPORT_FORMAT = Set.new(["xls", "csv", "pdf", "ods", "tsv", "html"])

        def key
          return self.id
        end
        
        # URL of worksheet-based feed of the spreadsheet.
        def worksheets_feed_url
          return "https://spreadsheets.google.com/feeds/worksheets/%s/private/full" %
              self.id
        end

        def document_feed_url
          return "https://docs.google.com/feeds/documents/private/full/" + CGI.escape(self.resource_id)
        end

        def spreadsheet_feed_url
          return "https://spreadsheets.google.com/feeds/spreadsheets/private/full/" + self.id
        end
        
        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Tables feed URL of the spreadsheet.
        def tables_feed_url
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they " +
              "will not be available after March 2012.")
          return "https://spreadsheets.google.com/feeds/%s/tables" % self.id
        end

        # Returns worksheets of the spreadsheet as array of GoogleDrive::Worksheet.
        def worksheets
          doc = @session.request(:get, self.worksheets_feed_url)
          if doc.root.name != "feed"
            raise(GoogleDrive::Error,
                "%s doesn't look like a worksheets feed URL because its root is not <feed>." %
                self.worksheets_feed_url)
          end
          result = []
          doc.css("entry").each() do |entry|
            title = entry.css("title").text
            updated = Time.parse(entry.css("updated").text)
            url = entry.css(
              "link[rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']")[0]["href"]
            result.push(Worksheet.new(@session, self, url, title, updated))
          end
          return result.freeze()
        end
        
        # Returns a GoogleDrive::Worksheet with the given title in the spreadsheet.
        #
        # Returns nil if not found. Returns the first one when multiple worksheets with the
        # title are found.
        def worksheet_by_title(title)
          return self.worksheets.find(){ |ws| ws.title == title }
        end

        # Adds a new worksheet to the spreadsheet. Returns added GoogleDrive::Worksheet.
        def add_worksheet(title, max_rows = 100, max_cols = 20)
          xml = <<-"EOS"
            <entry xmlns='http://www.w3.org/2005/Atom'
                   xmlns:gs='http://schemas.google.com/spreadsheets/2006'>
              <title>#{h(title)}</title>
              <gs:rowCount>#{h(max_rows)}</gs:rowCount>
              <gs:colCount>#{h(max_cols)}</gs:colCount>
            </entry>
          EOS
          doc = @session.request(:post, self.worksheets_feed_url, :data => xml)
          url = doc.css(
            "link[rel='http://schemas.google.com/spreadsheets/2006#cellsfeed']")[0]["href"]
          return Worksheet.new(@session, self, url, title)
        end

        # DEPRECATED: Table and Record feeds are deprecated and they will not be available after
        # March 2012.
        #
        # Returns list of tables in the spreadsheet.
        def tables
          warn(
              "DEPRECATED: Google Spreadsheet Table and Record feeds are deprecated and they " +
              "will not be available after March 2012.")
          doc = @session.request(:get, self.tables_feed_url)
          return doc.css("entry").map(){ |e| Table.new(@session, e) }.freeze()
        end
        
    end
    
end
