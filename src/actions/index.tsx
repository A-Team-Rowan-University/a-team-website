import * as constants from '../constants';
import * as types from '../types';

export interface SignIn {
    type: constants.SIGNIN;
    user: types.SignedInUser;
}

export function signIn(user: types.SignedInUser): SignIn {
    return {
        type: constants.SIGNIN,
        user,
    }
}

export type SignInAction = SignIn;

export type AppAction = SignIn;

