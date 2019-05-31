import React from 'react';
//import logo from '../resources/images/A-Team-Logo.png';
import {SignInButton} from './SignIn'
import {SignedInUser} from './SignIn'
import Tests from './Tests'
import Navigation from './Nav'
import Cookies from 'universal-cookie'
import config from '../config'
import Dashboard from './Dashboard'
import { BrowserRouter as Router} from 'react-router-dom'

const cookies = new Cookies()

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
        cookies.set('id_token', user.id_token, { path: '/' })
    }

    async renderPage() {
        if(this.state.user){
            return ( <Tests user={this.state.user} />)
        }
        else {
            const id_token = cookies.get('id_token')

            const headers = new Headers();
            headers.append("id_token", id_token);

            const init: RequestInit = {
                method: "GET",
                headers: headers,
            };

            let response = await fetch(config.api_url + "/tests/", init);

            if(response.ok) {
                const headers = new Headers();
                const init: RequestInit = {
                    method: "GET",
                    headers: headers,
                };

                let response = await fetch(`https://www.googleapis.com/oauth2/v2/tokeninfo?id_token=${id_token}`, init);
                return ( <p> You are logged in! </p> )
            }
            else
            {
                return ( <p> You are not logged in! </p> )
            }
        }
    }

    render() {
        return (
            <div className="App">
                <Navigation />
                <SignInButton onSignIn={this.onSignIn.bind(this)} />
                <Dashboard />
            </div>
        )
    }
}
