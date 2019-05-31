
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
import {SignedInUser} from './SignIn'
import config from './Config'
//import '../styles/template.css'

interface TestQuestionCategory {
    number_of_questions: number;
    question_category_id: number;
}

interface Test {
    id: number;
    creator_id: number;
    name: string;
    questions: TestQuestionCategory[];
}

interface NewTest {
    name: string;
    questions: TestQuestionCategory[];
}

interface TestList {
    tests: Test[]
}

interface TestProps {
    user: SignedInUser;
}

interface TestState {
    creating_test: boolean;
    tests: Test[];
}

export default class Tests extends React.Component<TestProps, TestState> {
    timer?: number;

    constructor(props: TestProps) {
        super(props);
        this.state = {
            creating_test: false,
            tests: [],
        };
    }

    async onTimeout() {

        if (!this.state.creating_test) {
            const headers = new Headers();
            headers.append("id_token", this.props.user.id_token);

            const init: RequestInit = {
                method: "GET",
                headers: headers,
            };

            let response = await fetch(config.api_url + "/tests/", init);

            let testList: TestList = await response.json();

            this.setState({tests: testList.tests})
        }
    }

    createOnRemove(test: Test) {
        return async () => {
            const headers = new Headers();
            headers.append("id_token", this.props.user.id_token);

            const init: RequestInit = {
                method: "DELETE",
                headers: headers,
            };

            let response = await fetch(config.api_url + "/tests/" + test.id, init);

            let testList: TestList = await response.json();

            this.setState({tests: testList.tests})
        };
    }

    componentDidMount() {
        this.timer = window.setInterval(() => this.onTimeout(), 1000)
    }

    componentWillUnmount() {
        window.clearInterval(this.timer);
    }

    createTest() {
        this.setState({creating_test: true});
    }

    onCreate() {
        this.setState({creating_test: false});
    }

    renderTestList() {
        return (
            <div>
                <ListGroup>
                    { this.state.tests.map((test) =>  (
                        <ListGroup.Item key={test.id.toString()}>
                            <h5>{test.name}</h5>
                            <Button
                                variant="danger"
                                onClick={this.createOnRemove(test)}
                            >Remove</Button>
                        </ListGroup.Item>
                    ))}
                </ListGroup>
                <Button
                    variant="primary"
                    onClick={this.createTest.bind(this)}
                >
                    Create a test
                </Button>
            </div>
            )
    }

    render() {
        if (this.state.creating_test) {
            return (
                <NewTestForm
                    user={this.props.user}
                    onCreate={this.onCreate.bind(this)}
                />
            )
        } else {
            return this.renderTestList();
        }
    }
}

interface Question {
    id: number,
    category_id: number,
    title: string,
    correct_answer: string,
    incorrect_answer_1: string,
    incorrect_answer_2: string,
    incorrect_answer_3: string,
}

interface QuestionCategory {
    id: number,
    title: string,
    questions: Question[],
}

interface QuestionCategoryList {
    question_categories: QuestionCategory[],
}

interface NewTestFormProps {
    user: SignedInUser;
    onCreate: () => void;
}

interface NewTestFormState {
    name: string;
    questions: TestQuestionCategory[];
    all_categories: QuestionCategory[];
    validated: boolean;
}

class NewTestForm extends React.Component<NewTestFormProps, NewTestFormState> {
    constructor(props: NewTestFormProps) {
        super(props);
        this.state = { name: "", questions: [] , all_categories: [] , validated: false};
    }

    async componentDidMount() {

        const headers = new Headers();
        headers.append("id_token", this.props.user.id_token);

        const init: RequestInit = {
            method: "GET",
            headers: headers,
        };

        let response = await fetch(config.api_url + "/question_categories/", init);

        let category_list: QuestionCategoryList = await response.json();

        this.setState({all_categories: category_list.question_categories})
    }

    onTitleChange(event: React.FormEvent<FormControlProps>) {
        let name = event.currentTarget.value;
        console.log(name);
        if (name) {
            this.setState({name});
        }
    }

    createOnCategoryChange(category: QuestionCategory) {
        return (event: React.FormEvent<FormControlProps>) => {

            let number_questions = Number(event.currentTarget.value);
            console.log(category.id + " " + event.currentTarget.value);

            this.setState((state: NewTestFormState, props: NewTestFormProps) => {
                let {questions} = this.state

                let index = questions
                    .findIndex((q: TestQuestionCategory, index: number) =>
                        q.question_category_id === category.id);

                if (number_questions === 0) {
                    if (index > -1) {
                        questions.splice(index, 1);
                    }
                } else {
                    if (index > -1) {
                        questions[index].number_of_questions = number_questions;
                    } else {
                        questions.push({
                            question_category_id: category.id,
                            number_of_questions: number_questions,
                        });
                    }
                }

                return { questions }
            });
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
            let new_test: NewTest = {
                name: this.state.name,
                questions: this.state.questions,
            }

            const headers = new Headers();
            headers.append("id_token", this.props.user.id_token);

            const init: RequestInit = {
                method: "POST",
                headers: headers,
                body: JSON.stringify(new_test),
            };

            await fetch(config.api_url + "/tests/", init);

            this.props.onCreate();
        }
    }

    isInvalid(category: QuestionCategory) {
        return this.state.questions.every((question: TestQuestionCategory) =>
            question.question_category_id === category.id &&
                question.number_of_questions >= category.questions.length
        );
    }

    renderValidation(category: QuestionCategory) {

        if (this.isInvalid(category)) {
            return ( <Alert variant="danger">Too many questions!</Alert> )
        } else {
            return ( <p></p> )
        }
    }

    renderCategories() {
        return this.state.all_categories.map((category: QuestionCategory) =>  (
            <InputGroup key={category.id}>
                <InputGroup.Prepend>
                    <InputGroup.Text>
                        {category.title}
                    </InputGroup.Text>
                </InputGroup.Prepend>
                <FormControl
                    type="number"
                    onChange={this.createOnCategoryChange(category)
                        .bind(this)}
                    defaultValue="0"
                    min="0"
                    max={category.questions.length}
                />
                <InputGroup.Append>
                    <InputGroup.Text>
                        / {category.questions.length}
                    </InputGroup.Text>
                </InputGroup.Append>
            </InputGroup>
        ));
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
                            <Form.Group controlId="newTestName">
                                <Form.Label>Test Name</Form.Label>
                                <Form.Control
                                    type="text"
                                    onChange={this.onTitleChange.bind(this)}
                                />
                            </Form.Group>
                        {this.renderCategories()}
                        <Button type="submit">Create Test!</Button>
                        </Form>
                    </Col>
                </Row>
            </Container>
        )
    }
}

