import React, { MouseEvent } from 'react'
//import logo from '../resources/images/A-Team-Logo.png'
import 'purecss/build/pure.css';

export default class Nav extends React.Component {
    render() {
        return (
            <header>
                <div className="container">
                    <nav>
                        <button className="navbutton">&#9776;</button>
                    </nav>
                    <div id="branding">
                        <img id="logo" src="media/A-Team-Logo.png" />
                        <h1>Template</h1>
                    </div>
                </div>
            </header>
        )
    }
}
