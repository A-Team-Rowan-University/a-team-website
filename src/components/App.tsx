import React from 'react';
//import logo from '../resources/images/A-Team-Logo.png';
import {Container} from 'react-bootstrap'
import {SignInButton} from './SignIn'
import {SignedInUser} from '../types'
import Cookies from 'universal-cookie'
import config from '../config'
import Dashboard from './Dashboard'
import { BrowserRouter as Router, Route, Link} from 'react-router-dom'

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
        if(this.state.user){
            return ( <p>You are signed in as {this.state.user.first_name}</p>)
        }
        else {
            return ( <p> You are not logged in! </p> )
        }
    }

    render() {
        return (
            <div className="App">
                <SignInButton onSignIn={this.onSignIn.bind(this)} />
            </div>
        )
    }
}

