
import React from 'react'
import {SignedInUser} from './SignIn'
import config from './Config'
import '../styles/template.css'

interface TestQuestionCategory {
    number_of_questions: number;
    questions_category_id: number;
}

interface Test {
    id: number;
    creator_id: number;
    name: string;
    questions: TestQuestionCategory[]
}

interface TestList {
    tests: Test[]
}

interface Props {
    user: SignedInUser;
}

interface State {
    tests: Test[];
}

export default class Tests extends React.Component<Props, State> {
    timer?: number;

    constructor(props: Props) {
        super(props);
        this.state = {
            tests: [],
        };
    }

    async onTimeout() {

        const headers = new Headers();
        headers.append("id_token", this.props.user.id_token);

        const init: RequestInit = {
            method: "GET",
            headers: headers,
        };

        let response = await fetch(config.api_url + "/tests/", init);

        console.log(response);
        console.log(response.headers);

        let testList: TestList = await response.json();

        this.setState({tests: testList.tests})
    }

    componentDidMount() {
        this.timer = window.setInterval(() => this.onTimeout(), 1000)
    }

    componentWillUnmount() {
        window.clearInterval(this.timer);
    }

    render() {
        return (
            <div>
                { this.state.tests.map((test) => <p>{test.name}</p>) }
            </div>
        )
    }
}
