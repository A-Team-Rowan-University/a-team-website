import React from 'react';
import logo from '../resources/images/A-Team-Logo.png';
import Nav from './Nav';
import '../styles/App.css';

const navProps: NavProp

export default class App extends React.Component {
    render() {
        return (
            <div className="App">
                <Nav />
            </div>
        )
    }
}
