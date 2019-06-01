import App from '../components/App';
import * as actions from '../actions';
import * as types from '../types';
import { AppState } from '../types/index';
import { connect } from 'react-redux';
import { Dispatch } from 'redux';

export function mapStateToProps({ user }: AppState) {
    return { user }
}

export function mapDispatchToProps(dispatch: Dispatch<actions.AppAction>) {
    return {
        onSignIn: (user: types.SignedInUser) => dispatch(actions.signIn(user)),
    }
}

export default connect(mapStateToProps, mapDispatchToProps)(App);

