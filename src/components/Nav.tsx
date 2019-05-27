import React, { MouseEvent } from 'react'
import logo from '../resources/images/A-Team-Logo.png'
import '../styles/template.css'

interface NavProps {
  options: Array<NavOption>;
  active: boolean;
}

class NavOption {
  constructor() {
  }
}

type NavState = Readonly<NavProps>;

export default class Nav extends React.Component<any, NavState> {
  constructor(props: NavProps) {
    super(props)
  }

  /**
   *  slides out side nav menu
   */
  opennav() {
  }

  render() {
    return (
      <>
        <header>
          <div className="container">
            <nav>
              <button className="navbutton" onClick={this.opennav}>&#9776;</button>
            </nav>
            <div id="branding">
              <img id="logo" src={logo} />
              <h1>Template</h1>
            </div>
          </div>
        </header>
        
        <div className="slidenav">
          <h1>Hello World!</h1>
        </div>
      </>

    );
  }
}