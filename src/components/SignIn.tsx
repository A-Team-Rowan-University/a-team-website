import React from 'react'
import GoogleLogin from 'react-google-login';
import '../styles/template.css'

export interface SignedInUser {
    id_token: string;
    first_name: string;
    last_name: string;
    email: string;
    profile_image_url: string;
}

interface Props {
    onSignIn: (user: SignedInUser) => void;
}

interface State {
    user?: SignedInUser;
}

export class SignInButton extends React.Component<Props, State> {
    constructor(props: Props) {
        super(props);
        this.state = { user: undefined };
    }

    onSignIn(googleUser: any) {
        let profile = googleUser.getBasicProfile();
        let auth = googleUser.getAuthResponse();

        let user: SignedInUser = {
            id_token: auth.id_token,
            first_name: profile.getGivenName(),
            last_name: profile.getFamilyName(),
            email: profile.getEmail(),
            profile_image_url: profile.getImageUrl(),
        }

        this.props.onSignIn(user);

        this.setState({user});
    }

    renderSignIn() {
        return (
            <GoogleLogin
                clientId="918184954544-jm1aufr31fi6sdjs1140p7p3rouaka14.apps.googleusercontent.com"
                buttonText="Login"
                onSuccess={this.onSignIn.bind(this)}
                onFailure={this.onSignIn.bind(this)}
                cookiePolicy={'single_host_origin'}
            />
        )
    }

    render() {
        if (this.state.user) {
            return (
                <span>
                    <p>{this.state.user.first_name} {this.state.user.last_name}</p>
                    <img alt="" src={this.state.user.profile_image_url} />
                </span>
            )
        } else {
            return this.renderSignIn();
        }
    }
}


