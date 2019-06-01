
import * as backend from './backend';

export interface SignedInUser {
    id_token: string;
    first_name: string;
    last_name: string;
    email: string;
    profile_image_url: string;
    access: backend.Access[];
}

export interface TestListState {
    tests: backend.Test[]
}

export interface AppState {
    user?: SignedInUser;
}

