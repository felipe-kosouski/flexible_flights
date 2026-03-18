namespace :airports do
  desc "Process airports.csv into app/javascript/data/airports.js (large + medium airports with IATA codes)"
  task :build do
    require "csv"
    require "json"

    csv_path = Rails.root.join("airports.csv")
    output_path = Rails.root.join("app/javascript/data/airports.js")

    abort "airports.csv not found at #{csv_path}" unless File.exist?(csv_path)

    airports = []

    CSV.foreach(csv_path, headers: true) do |row|
      next unless %w[large_airport medium_airport].include?(row["type"])
      next if row["iata_code"].nil? || row["iata_code"].strip.empty?

      airports << {
        iata: row["iata_code"].strip,
        name: row["name"].to_s.strip,
        city: row["municipality"].to_s.strip,
        country: row["iso_country"].to_s.strip
      }
    end

    airports.sort_by! { |a| a[:iata] }

    FileUtils.mkdir_p(output_path.dirname)

    File.write(output_path, "export default #{JSON.generate(airports)};\n")

    puts "Done. #{airports.size} airports written to #{output_path}"
  end
end
