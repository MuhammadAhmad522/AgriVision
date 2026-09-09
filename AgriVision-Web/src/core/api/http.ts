import { auth, getCachedAuthToken } from '../auth/firebase';

export interface ApiErrorResponse {
  error?: {
    code: string;
    message: string;
    status_code: number;
    retryable?: boolean;
    details?: any;
  };
  detail?: any;
}

export class ApiHttpError extends Error {
  statusCode: number;
  code: string;
  retryable: boolean;

  constructor(statusCode: number, message: string, code = 'http_error', retryable = false) {
    super(message);
    this.name = 'ApiHttpError';
    this.statusCode = statusCode;
    this.code = code;
    this.retryable = retryable;
  }
}

export class HttpClient {
  private baseURL: string;

  constructor() {
    // If VITE_API_URL is explicitly empty string, it will use relative paths (perfect for our Nginx reverse proxy)
    const envUrl = import.meta.env.VITE_API_URL;
    this.baseURL = envUrl !== undefined ? envUrl : 'http://127.0.0.1:8000';
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
      const cached = getCachedAuthToken();
      if (cached) {
        headers['Authorization'] = `Bearer ${cached}`;
      } else if (auth.currentUser) {
        const token = await auth.currentUser.getIdToken();
        headers['Authorization'] = `Bearer ${token}`;
      }
    } catch (e) {
      console.warn('Failed to get auth token', e);
    }

    return headers;
  }

  private async handleResponse<T>(res: Response): Promise<T> {
    if (!res.ok) {
      let errorMessage = `HTTP ${res.status}: ${res.statusText}`;
      let errorCode = 'http_error';
      let retryable = false;

      try {
        const errData: ApiErrorResponse = await res.json();
        if (errData?.error) {
          errorMessage = errData.error.message || errorMessage;
          errorCode = errData.error.code || errorCode;
          retryable = Boolean(errData.error.retryable);
        } else if (errData?.detail) {
          errorMessage = typeof errData.detail === 'string' ? errData.detail : JSON.stringify(errData.detail);
        }
      } catch {
        // Fallback if not valid JSON
      }

      throw new ApiHttpError(res.status, errorMessage, errorCode, retryable);
    }

    if (res.status === 204) return {} as T;
    return await res.json();
  }

  async get<T>(endpoint: string): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'GET',
      headers: await this.getAuthHeaders()
    });
    return await this.handleResponse<T>(res);
  }

  async post<T>(endpoint: string, body?: any, options?: { headers?: Record<string, string> }): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'POST',
      headers: { ...(await this.getAuthHeaders()), ...(options?.headers || {}) },
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    return await this.handleResponse<T>(res);
  }

  async put<T>(endpoint: string, body?: any, options?: { headers?: Record<string, string> }): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'PUT',
      headers: { ...(await this.getAuthHeaders()), ...(options?.headers || {}) },
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    return await this.handleResponse<T>(res);
  }

  async patch<T>(endpoint: string, body?: any, options?: { headers?: Record<string, string> }): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'PATCH',
      headers: { ...(await this.getAuthHeaders()), ...(options?.headers || {}) },
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    return await this.handleResponse<T>(res);
  }

  /**
   * Fetches an authenticated file response and hands it to the browser as a download.
   * A plain anchor href cannot be used because these endpoints require a bearer token.
   */
  async downloadFile(endpoint: string, filename: string): Promise<void> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'GET',
      headers: await this.getAuthHeaders()
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    try {
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = filename;
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
    } finally {
      // Release the object URL once the browser has taken the download.
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
  }

  async delete<T>(endpoint: string): Promise<T> {
    const res = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'DELETE',
      headers: await this.getAuthHeaders()
    });
    return await this.handleResponse<T>(res);
  }
}

export const http = new HttpClient();
