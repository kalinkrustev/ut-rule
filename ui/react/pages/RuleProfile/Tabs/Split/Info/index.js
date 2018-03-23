import React, { PropTypes } from 'react';
import Input from 'ut-front-react/components/Input';
import MultiSelectBubble from 'ut-front-react/components/MultiSelectBubble';
import { splitTags } from '../../../../../../../config';
import {fromJS} from 'immutable';
import style from '../../style.css';

export const Info = (props) => {
    const {
        changeInputField,
        selectedTags,
        name,
        errors
    } = props;
    return (
        <div>
            <div className={style.inputWrapper}>
                <Input
                  keyProp={'name'}
                  label='Split Name'
                  isValid={!errors.getIn(['name'])}
                  errorMessage={errors.getIn(['name'])}
                  value={name}
                  onChange={(field) => changeInputField(field)}
                />
            </div>
            <div className={style.inputWrapper}>
                <MultiSelectBubble
                  name='tag'
                  label={'Tag'}
                  value={selectedTags}
                  options={splitTags}
                  onChange={(value) => { changeInputField({key: 'tags', value}); }}
                />
            </div>
        </div>
    );
};

Info.propTypes = {
    changeInputField: PropTypes.func,
    selectedTags: PropTypes.array,
    name: PropTypes.string,
    errors: PropTypes.object // immutable
};

Info.defaultProps = {
    errors: fromJS({})
};

export default Info;
