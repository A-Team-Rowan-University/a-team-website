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
    .getElementById("sidenav").style.width = "24em";

    var acc = document.getElementsByClassName("accordionMenu");
    /* finds every element with the class id accodian and addes them to a list */
    var i;

    for (i = 0; i < acc.length; i++) {
      acc[i].addEventListener("click", function () {/* makes said elements open/close their respective drop down menu when clicked*/
        this.classList.toggle("active");
        var panel = this.nextElementSibling;
        if (panel.style.display === "block") {
          panel.style.display = "none";
        } else {
          panel.style.display = "block";
        }
      });
    }
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