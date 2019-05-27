import React from 'react';
//import logo from '../resources/images/A-Team-Logo.png';
import {SignInButton} from './SignIn'
import {SignedInUser} from './SignIn'
import Tests from './Tests'
import '../styles/App.css';

interface Props {

}

interface State {
    user?: SignedInUser;
}

export default class App extends React.Component<Props, State> {

    constructor(props: Props) {
        super(props);
        this.state = { user: undefined };
    }

    onSignIn(user: SignedInUser) {
        console.log(this);
        this.setState((state, props) => ({user}));
    }

    renderPage() {
        if (this.state.user) {
            return (
                <Tests user={this.state.user}/>
            )
        } else {
            return (
                <p> You are not logged in! </p>
            )
        }
    }

    render() {
        return (
            <div className="App">
                <SignInButton onSignIn={this.onSignIn.bind(this)} />
                { this.renderPage() }
            </div>
        )
    }
}
