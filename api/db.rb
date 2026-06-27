require "sequel"

module FnmnlDemo
  module_function

  def connect_database
    @db&.disconnect
    @db = Sequel.connect(ENV.fetch("DATABASE_URL"), max_connections: Integer(ENV.fetch("DB_POOL", "12")))
  end

  def db
    @db ||= connect_database
  end

  def migrate!
    db.create_table?(:artists) do
      primary_key :id
      String :name, null: false
      String :home_city, null: false
      String :sound, null: false
      String :image_url, null: false
      DateTime :created_at, null: false
    end

    db.create_table?(:events) do
      primary_key :id
      String :title, null: false
      String :city, null: false
      String :venue, null: false
      Date :event_date, null: false
      Integer :capacity, null: false
      foreign_key :headliner_id, :artists
      index :event_date
      index :city
    end

    db.create_table?(:releases) do
      primary_key :id
      String :title, null: false
      String :label, null: false
      Date :release_date, null: false
      foreign_key :artist_id, :artists
      index :release_date
    end

    db.create_table?(:follows) do
      primary_key :id
      String :email, null: false
      foreign_key :artist_id, :artists
      DateTime :created_at, null: false
      index [:email, :artist_id], unique: true
    end
  end

  def seed!
    return unless db[:artists].empty?

    now = Time.now
    artists = [
      { name: "Kora Phase", home_city: "Berlin", sound: "deep techno / dub pressure", image_url: "https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=900&q=80", created_at: now },
      { name: "Mara Circuit", home_city: "Lisbon", sound: "breaks / hardware electro", image_url: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=900&q=80", created_at: now },
      { name: "Lumen Fold", home_city: "New York", sound: "ambient club / leftfield house", image_url: "https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=900&q=80", created_at: now }
    ]

    artist_ids = artists.map { |artist| db[:artists].insert(artist) }
    db[:events].multi_insert([
      { title: "Limited Beta Warehouse", city: "Berlin", venue: "Nullraum", event_date: Date.today + 9, capacity: 450, headliner_id: artist_ids[0] },
      { title: "Transatlantic Listening Room", city: "New York", venue: "Public Records", event_date: Date.today + 18, capacity: 280, headliner_id: artist_ids[2] },
      { title: "Harbor Frequency", city: "Lisbon", venue: "Ministerium", event_date: Date.today + 30, capacity: 520, headliner_id: artist_ids[1] }
    ])
    db[:releases].multi_insert([
      { title: "Subsurface Index", label: "FNMNL", release_date: Date.today - 14, artist_id: artist_ids[0] },
      { title: "Patch Bay Dreams", label: "FNMNL", release_date: Date.today - 6, artist_id: artist_ids[1] },
      { title: "Afterimage Maps", label: "FNMNL", release_date: Date.today + 7, artist_id: artist_ids[2] }
    ])
  end
end
