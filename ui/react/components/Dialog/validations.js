import joi from 'joi-browser';

/** Joi API ref: https://github.com/hapijs/joi/blob/v9.2.0/lib/language.js */
let schema = joi.object().keys({
    condition: joi.array().items(
        joi.object().keys({
            priority: joi.number().min(1).required().options({
                language: {
                    key: '"Priority" ',
                    string: {
                        min: 'is required for all conditions',
                        number: 'is required for all conditions'
                    }
                }
            })
        })
    ),
    limit: joi.array().items(
        joi.object().keys({
            currency: joi.string().required().options({
                language: {
                    key: '"Currency" ',
                    string: {
                        base: 'is required for all limits'
                    }
                }
            }),
            minAmount: joi.number().optional().allow(null),
            maxAmount: joi.number().optional().allow(null),
            maxAmountDaily: joi.number().optional().allow(null),
            maxCountDaily: joi.number().optional().allow(null),
            maxAmountWeekly: joi.number().optional().allow(null),
            maxCountWeekly: joi.number().optional().allow(null),
            maxAmountMonthly: joi.number().optional().allow(null),
            maxCountMonthly: joi.number().optional().allow(null)
        })
    ),
    split: joi.array().items(
        joi.object().keys({
            splitName: joi.object().keys({
                name: joi.string().required().options({
                    language: {
                        key: '"Split Name" ',
                        string: {
                            base: 'is required for all splits'
                        }
                    }
                })
            }),
            splitRange: joi.array().items(
                 joi.object().keys({
                     startAmount: joi.number().min(1).required().options({
                         language: {
                             key: '"Range Start Amount" ',
                             number: {
                                 base: 'is required for all splits'
                             }
                         }
                     }),
                     startAmountCurrency: joi.string().required().options({
                         language: {
                             key: '"Range Start Amount Currency" ',
                             string: {
                                 base: 'is required for all splits'
                             }
                         }
                     }),
                     percent: joi.number().optional().allow(null),
                     minValue: joi.number().optional().allow(null),
                     maxValue: joi.number().optional().allow(null)
                 })
            ),
            splitAssignment: joi.array().items(
                joi.object().keys({
                    debit: joi.string().required().options({
                        language: {
                            key: '"Assignment Debit" ',
                            string: {
                                base: 'is required for all splits'
                            }
                        }
                    }),
                    credit: joi.string().required().options({
                        language: {
                            key: '"Assignment Credit" ',
                            string: {
                                base: 'is required for all splits'
                            }
                        }
                    }),
                    description: joi.string().required().options({
                        language: {
                            key: '"Assignment Description" ',
                            string: {
                                base: 'is required for all splits'
                            }
                        }
                    }),
                    percent: joi.number().optional().allow(null),
                    minValue: joi.number().optional().allow(null),
                    maxValue: joi.number().optional().allow(null)
                })
            )
        })
    )
});
module.exports = {
    run: (objToValidate, options = {}) => {
        return joi.validate(objToValidate, schema, Object.assign({}, {
            allowUnknown: true,
            abortEarly: false
        }, options), (err, value) => {
            debugger;
            if (!err) {
                return {
                    isValid: true
                };
            }
            let errors = err.details.reduce((errorArray, current) => {
                if (errorArray.indexOf(current.message) === -1) {
                    errorArray.push(current.message);
                }
                return errorArray;
            }, []);
            return {
                isValid: errors.length === 0,
                errors: errors
            };
        });
    }
};
