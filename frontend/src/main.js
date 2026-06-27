import { createApp } from "vue";
import "./styles.css";

const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:4567";

createApp({
  data() {
    return {
      catalog: null,
      selectedArtist: null,
      email: "",
      status: "loading",
      followStatus: "",
      error: ""
    };
  },
  computed: {
    artists() {
      return this.catalog?.artists || [];
    },
    selectedArtistEvents() {
      if (!this.selectedArtist) return [];
      return this.catalog.events.filter((event) => event.headliner === this.selectedArtist.name);
    }
  },
  async mounted() {
    await this.loadCatalog();
  },
  methods: {
    async loadCatalog() {
      this.status = "loading";
      this.error = "";
      try {
        const response = await fetch(`${API_BASE}/api/catalog`);
        if (!response.ok) throw new Error(`catalog returned ${response.status}`);
        this.catalog = await response.json();
        this.selectedArtist = this.catalog.artists[0];
        this.status = "ready";
      } catch (error) {
        this.status = "error";
        this.error = error.message;
      }
    },
    async followArtist() {
      if (!this.selectedArtist || !this.email) return;
      this.followStatus = "saving";
      const response = await fetch(`${API_BASE}/api/follows`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: this.email, artist_id: this.selectedArtist.id })
      });
      this.followStatus = response.ok ? "saved" : "failed";
    },
    apiUrl(path) {
      return `${API_BASE}${path}`;
    }
  },
  template: `
    <main class="shell">
      <section class="hero">
        <div>
          <p class="eyebrow">Ruby + Sinatra + Postgres + Railway + Cloudflare + Vue 3</p>
          <h1>FNMNL infrastructure demo</h1>
          <p class="lede">A small electronic music platform slice for reasoning about burst traffic, cacheable reads, write paths, health checks, load tests, and observability.</p>
        </div>
        <div class="ops-panel">
          <span :class="['pill', status]">{{ status }}</span>
          <a :href="apiUrl('/healthz')" target="_blank">healthz</a>
          <a :href="apiUrl('/readyz')" target="_blank">readyz</a>
          <a :href="apiUrl('/metrics')" target="_blank">metrics</a>
        </div>
      </section>

      <p v-if="error" class="error">{{ error }}</p>

      <section v-if="catalog" class="grid">
        <article class="feature">
          <img :src="selectedArtist.image_url" :alt="selectedArtist.name" />
          <div class="feature-copy">
            <p class="eyebrow">Featured artist</p>
            <h2>{{ selectedArtist.name }}</h2>
            <p>{{ selectedArtist.sound }} from {{ selectedArtist.home_city }}</p>
            <form @submit.prevent="followArtist" class="follow-form">
              <input v-model="email" type="email" placeholder="you@example.com" aria-label="Email address" />
              <button type="submit">Follow</button>
            </form>
            <p class="form-status">{{ followStatus }}</p>
          </div>
        </article>

        <aside class="list-panel">
          <h2>Artists</h2>
          <button v-for="artist in artists" :key="artist.id" @click="selectedArtist = artist" :class="{ active: selectedArtist?.id === artist.id }">
            <span>{{ artist.name }}</span>
            <small>{{ artist.home_city }}</small>
          </button>
        </aside>
      </section>

      <section v-if="catalog" class="columns">
        <div>
          <h2>Upcoming shows</h2>
          <article v-for="event in catalog.events" :key="event.id" class="row">
            <strong>{{ event.title }}</strong>
            <span>{{ event.city }} · {{ event.venue }} · cap {{ event.capacity }}</span>
          </article>
        </div>
        <div>
          <h2>Releases</h2>
          <article v-for="release in catalog.releases" :key="release.id" class="row">
            <strong>{{ release.title }}</strong>
            <span>{{ release.artist }} · {{ release.label }} · {{ release.release_date }}</span>
          </article>
        </div>
        <div>
          <h2>Infra readout</h2>
          <article class="row">
            <strong>Cached catalog</strong>
            <span>Public GETs set browser and shared-cache TTLs for Cloudflare.</span>
          </article>
          <article class="row">
            <strong>Burst writes isolated</strong>
            <span>Follow POSTs hit Postgres directly and can be rate-limited at the edge.</span>
          </article>
          <article class="row">
            <strong>Scale target</strong>
            <span>Use k6 to validate 500 RPS while watching p95 latency and DB pool pressure.</span>
          </article>
        </div>
      </section>
    </main>
  `
}).mount("#app");
