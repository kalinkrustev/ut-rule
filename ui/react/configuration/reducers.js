import * as actionTypes from './actionTypes';
import immutable from 'immutable';

const defaultUiState = {
    nomenclatures: {
        itemName: [
            'country',
            'channel',
            'region',
            'city',
            'organization',
            'role',
            'operation',
            'supervisor',
            'cardProduct',
            'accountProduct',
            'account'
        ],
        itemCode: [
        ],
        agentRole: [
        ],
        accountAlias: [
        ]
    },
    main: {
        grid: {
            columns: {
                priority: {
                    visible: true,
                    title: 'Priority'
                },
                channel: {
                    visible: true,
                    title: 'Channel'
                },
                operation: {
                    visible: true,
                    title: 'Operation'
                },
                source: {
                    visible: true,
                    title: 'Source'
                },
                destination: {
                    visible: true,
                    title: 'Destination'
                },
                limit: {
                    visible: true,
                    title: 'Limit'
                }
            }
        }
    },
    dialog: {
        sections: {
            channel: {
                visible: true,
                title: 'Channel',
                fields: {
                    channel: {
                        visible: true,
                        title: 'Type'
                    },
                    country: {
                        visible: true,
                        title: 'Country'
                    },
                    region: {
                        visible: true,
                        title: 'Region'
                    },
                    city: {
                        visible: true,
                        title: 'City'
                    },
                    organization: {
                        visible: true,
                        title: 'Organization'
                    },
                    supervisor: {
                        visible: true,
                        title: 'Supervisor'
                    },
                    tag: {
                        visible: true,
                        title: 'Tag'
                    },
                    role: {
                        visible: true,
                        title: 'Channel role'
                    }
                }
            },
            operation: {
                visible: true,
                title: 'Operation',
                fields: {
                    tag: {
                        visible: true,
                        title: 'Tag'
                    },
                    operationStartDate: {
                        visible: true,
                        title: 'Start Date'
                    },
                    operationEndDate: {
                        visible: true,
                        title: 'End Date'
                    },
                    operationId: {
                        visible: true,
                        title: 'Operation'
                    }
                }
            },
            source: {
                visible: true,
                title: 'Source',
                fields: {
                    country: {
                        visible: true,
                        title: 'Country'
                    },
                    region: {
                        visible: true,
                        title: 'Region'
                    },
                    city: {
                        visible: true,
                        title: 'City'
                    },
                    organization: {
                        visible: true,
                        title: 'Organization'
                    },
                    supervisor: {
                        visible: true,
                        title: 'Supervisor'
                    },
                    tag: {
                        visible: true,
                        title: 'Tag'
                    },
                    cardProduct: {
                        visible: true,
                        title: 'Card Product'
                    },
                    accountProduct: {
                        visible: true,
                        title: 'Account Product'
                    },
                    account: {
                        visible: true,
                        title: 'Account'
                    }
                }
            },
            destination: {
                visible: true,
                title: 'Destination',
                fields: {
                    country: {
                        visible: true,
                        title: 'Country'
                    },
                    region: {
                        visible: true,
                        title: 'Region'
                    },
                    city: {
                        visible: true,
                        title: 'City'
                    },
                    organization: {
                        visible: true,
                        title: 'Organization'
                    },
                    supervisor: {
                        visible: true,
                        title: 'Supervisor'
                    },
                    tag: {
                        visible: true,
                        title: 'Tag'
                    },
                    cardProduct: {
                        visible: true,
                        title: 'Card Product'
                    },
                    accountProduct: {
                        visible: true,
                        title: 'Account Product'
                    },
                    account: {
                        visible: true,
                        title: 'Account'
                    }
                }
            },
            limit: {
                visible: true,
                title: 'Limit'
            },
            split: {
                visible: true,
                title: 'Split',
                assignmentFields: {
                    description: {
                        visible: true,
                        title: 'Description'
                    },
                    debit: {
                        visible: true,
                        title: 'Debit'
                    },
                    debitAlias: {
                        visible: false,
                        title: 'Debit'
                    },
                    credit: {
                        visible: true,
                        title: 'Credit'
                    },
                    creditAlias: {
                        visible: false,
                        title: 'Credit'
                    },
                    percent: {
                        visible: true,
                        title: '%'
                    },
                    minValue: {
                        visible: true,
                        title: 'Min Amount'
                    },
                    maxValue: {
                        visible: true,
                        title: 'Max Amount'
                    }
                }
            },
            summary: {
                visible: true,
                title: 'Summary'
            }
        }
    }
};

const defaultStateImmutable = immutable.fromJS(defaultUiState);

export function uiConfig(state = defaultStateImmutable, action) {
    switch (action.type) {
        case actionTypes.SET_RULE_CONFIG:
            if (action.config) {
                let passedConfigAsImmutable = immutable.fromJS(action.config);
                let newConfigState = state.mergeDeep(passedConfigAsImmutable);
                return newConfigState;
            }
    }

    return state;
}

export default { uiConfig };