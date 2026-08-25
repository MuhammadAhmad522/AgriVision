export class HttpClient {
  private baseURL: string;

  constructor() {
    this.baseURL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
  }

  getBaseURL(): string {
    return this.baseURL;
  }

  private async getAuthHeaders(): Promise<HeadersInit> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Client': 'web'
    };

    try {
      const { auth } = await import('../auth/firebase');
      const user = auth.currentUser;
      if (user) {
        const token = await user.getIdToken();
        headers['Authorization'] = `Bearer ${token}`;
      }
    } catch (e) {
      console.warn('Failed to get auth token', e);
    }

    return headers;
  }

  async get<T>(endpoint: string): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'GET',
      headers: await this.getAuthHeaders()
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    return await res.json();
  }

  async post<T>(endpoint: string, body?: any, options?: { headers?: Record<string, string> }): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'POST',
      headers: { ...(await this.getAuthHeaders()), ...(options?.headers || {}) },
      body: body ? JSON.stringify(body) : undefined
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    // 204 No Content won't have JSON
    if (res.status === 204) return {} as T;
    return await res.json();
  }

  async delete<T>(endpoint: string): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'DELETE',
      headers: await this.getAuthHeaders()
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    if (res.status === 204) return {} as T;
    return await res.json();
  }
}

export const http = new HttpClient();
