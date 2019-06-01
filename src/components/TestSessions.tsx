import React from 'react'
import {
    Container,
    Row,
    Col,
    Form,
    FormControl,
    FormControlProps,
    InputGroup,
    Button,
    ListGroup,
    Alert,
} from 'react-bootstrap'
import {SignedInUser} from '../types'
//import {Test, TestList} from './Tests'
import config from './Config'
//import '../styles/template.css'

interface TestSessionRegistration {
    id: number,
    taker_id: number,
    registered: string,
    opened_test?: string,
    submitted_test?: string,
    score?: number,
}


interface TestSession {
    id: number,
    test_id: number,
    name: string,
    registrations: TestSessionRegistration[],
    registrations_enabled: boolean,
    opening_enabled: boolean,
    submissions_enabled: boolean,
}

interface NewTestSession {
    test_id: number,
    name: string,
}

interface TestSessionList {
    test_sessions: TestSession[]
}

interface TestSessionProps {
    user: SignedInUser;
}

interface TestSessionState {
    creating_test_session: boolean;
    test_sessions: TestSession[];
}

export default class TestSessions extends React.Component<TestSessionProps, TestSessionState> {
    timer?: number;

    constructor(props: TestSessionProps) {
        super(props);
        this.state = {
            creating_test_session: false,
            test_sessions: [],
        };
    }

    async onTimeout() {

        if (!this.state.creating_test_session) {
            const headers = new Headers();
            headers.append("id_token", this.props.user.id_token);

            const init: RequestInit = {
                method: "GET",
                headers: headers,
            };

            let response = await fetch(config.api_url + "/test_sessions/", init);

            let testSessionList: TestSessionList = await response.json();

            this.setState({test_sessions: testSessionList.test_sessions})
        }
    }

    createOnRemove(test_session: TestSession) {
        return async () => {
            const headers = new Headers();
            headers.append("id_token", this.props.user.id_token);

            const init: RequestInit = {
                method: "DELETE",
                headers: headers,
            };

            await fetch(config.api_url + "/test_sessions/" + test_session.id, init);
        };
    }

    componentDidMount() {
        this.timer = window.setInterval(() => this.onTimeout(), 1000)
    }

    componentWillUnmount() {
        window.clearInterval(this.timer);
    }

    createTestSession() {
        this.setState({creating_test_session: true});
    }

    onCreate() {
        this.setState({creating_test_session: false});
    }

    render() {
        return (
            <div>
                <ListGroup>
                    { this.state.test_sessions.map((test_session) =>  (
                        <ListGroup.Item key={test_session.id.toString()}>
                            <h5>{test_session.name}</h5>
                            <Button
                                variant="danger"
                                onClick={this.createOnRemove(test_session)}
                            >Remove</Button>
                        </ListGroup.Item>
                    ))}
                </ListGroup>
                <Button
                    variant="primary"
                    onClick={this.createTestSession.bind(this)}
                >
                    Create a test
                </Button>
            </div>
            )
    }
}

interface NewTestSessionFormProps {
    user: SignedInUser;
    test_id: number;
    onCreate: () => void;
}

interface NewTestSessionFormState {
    name: string;
    validated: boolean;
}

export class NewTestSessionForm extends React.Component<NewTestSessionFormProps, NewTestSessionFormState> {
    constructor(props: NewTestSessionFormProps) {
        super(props);
        this.state = { name: "", validated: false};
    }

    onTitleChange(event: React.FormEvent<FormControlProps>) {
        let name = event.currentTarget.value;
        console.log(name);
        if (name) {
            this.setState({name});
        }
    }

    async onCreate(event: React.FormEvent<HTMLFormElement>) {

        event.preventDefault();
        event.stopPropagation();

        console.log("Submitting");

        const form = event.currentTarget;

        this.setState({validated: true});

        if (form.checkValidity() !== false) {
            console.log("Sending request");
            let new_test_session: NewTestSession = {
                test_id: this.props.test_id,
                name: this.state.name,
            }

            const headers = new Headers();
            headers.append("id_token", this.props.user.id_token);

            const init: RequestInit = {
                method: "POST",
                headers: headers,
                body: JSON.stringify(new_test_session),
            };

            await fetch(config.api_url + "/test_sessions/", init);

            this.props.onCreate();
        }
    }

    render() {
        return (
            <Container>
                <Row>
                    <Col>
                        <Form
                            validated={this.state.validated}
                            onSubmit={this.onCreate.bind(this)}
                        >
                            <Form.Group controlId="newTestSessionName">
                                <Form.Label>Test Session Name</Form.Label>
                                <Form.Control
                                    type="text"
                                    onChange={this.onTitleChange.bind(this)}
                                />
                            </Form.Group>
                        <Button type="submit">Create Test Session!</Button>
                        </Form>
                    </Col>
                </Row>
            </Container>
        )
    }
}

