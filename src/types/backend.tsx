
/**
 * Types that define the inteface to the backend
 */

export interface Access {
    id: number;
    access_name: string;
}

export interface AccessList {
    accesses: Access[];
}

export interface TestQuestionCategory {
    number_of_questions: number;
    question_category_id: number;
}

export interface Test {
    id: number;
    creator_id: number;
    name: string;
    questions: TestQuestionCategory[];
}

export interface NewTest {
    name: string;
    questions: TestQuestionCategory[];
}

export interface TestList {
    tests: Test[]
}

