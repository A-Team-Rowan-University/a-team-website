import React, { MouseEvent } from 'react'
import {Navbar, Nav, NavDropdown} from 'react-bootstrap'
import logo from '../resources/images/A-Team-Logo.png'
import {SignedInUser} from './SignIn'

export default class Navigation extends React.Component<NavigationProps> {

    componentWillMount() {

    }

    render() {
        return (
            <Navbar collapseOnSelect expand="lg" bg="dark" variant="dark">
                <Navbar.Brand href="/"> <img alt="" src={logo} width="30" height="30" className="d-inline-block align-top" />
                    {' A-Team at Rowan University'}
                </Navbar.Brand>
                <Navbar.Toggle aria-controls="responsive-navbar-nav" />
                <Navbar.Collapse id="responsive-navbar-nav">
                    <Nav className="mr-auto">
                        <Nav.Link href="/tests">Tests</Nav.Link>
                        <Nav.Link href="/users">Users</Nav.Link>
                    </Nav>
                    <Nav>
                        <Nav.Link href="/sign_in">SignIn</Nav.Link>
                    </Nav>
                </Navbar.Collapse>
            </Navbar>
        )}
}

interface NavigationProps {
    user?: SignedInUser
}
