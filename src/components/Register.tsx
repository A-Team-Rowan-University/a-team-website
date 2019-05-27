import React from 'react'
import '../styles/template.css'

export interface Props {
    name: string;
}

export interface State {
    count: number;
}

export default class Registration extends React.Component<Props, State> {
    constructor(props: Props) {
        super(props);
        this.state = {count: 0};
    }

    componentDidMount() {

    }

    componentWillUnmount() {

    }

    onIncrement() {
        this.setState((state, props) => ({
            count: state.count + 1
        }));
    }

    render() {
        return (
            <div>
                <h1>Hello, {this.props.name}! {this.state.count}</h1>
                <button onClick={this.onIncrement.bind(this)}>+</button>
            </div>
        )
    }
}

