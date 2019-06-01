
import { AppAction } from '../actions';
import { AppState } from '../types';
import { SIGNIN } from '../constants';

export function app(state: AppState, action: AppAction): AppState {
    switch (action.type) {
        case SIGNIN:
            return { ...state, user: action.user };
    }
    return state;
}
