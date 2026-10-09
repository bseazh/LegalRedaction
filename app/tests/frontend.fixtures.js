function entity(text, value, type, source = 'ner', from = 0) {
  const start = text.indexOf(value, from);
  if (start < 0) throw new Error(`Fixture value not found: ${value}`);
  return {type, value, start, end: start + value.length, source};
}

const shortText = '原告张伟起诉华星科技有限公司，联系电话13800138000，案号（2026）粤0305民初123号。';
const repeatedText = '张伟与李娜签订协议。张伟随后委托李娜办理交割。';
const rolesText = '原告张伟诉被告李娜合同纠纷一案，代理律师王强来自海湾律师事务所，深圳市南山区人民法院依法审理。';
const longParagraph = '申请人陈明向远航科技有限公司主张权利，联系地址为深圳市福田区深南大道100号。';
const longText = Array.from({length: 90}, (_, index) => `${index + 1}. ${longParagraph}`).join('\n');
const zeroText = '本协议自签署之日起生效，履行期限为三十日。争议应依照中华人民共和国民法典处理。';

const repeatedFirst = repeatedText.indexOf('张伟');
const repeatedSecond = repeatedText.indexOf('张伟', repeatedFirst + 1);

export const FIXTURES = {
  'short.txt': {
    name: 'short.txt', text: shortText, entities: [
      entity(shortText, '张伟', 'PLAINTIFF'),
      entity(shortText, '华星科技有限公司', 'ORGANIZATION'),
      entity(shortText, '13800138000', 'PHONE', 'rule'),
      entity(shortText, '（2026）粤0305民初123号', 'CASE_NUMBER', 'rule')
    ]
  },
  'long.txt': {
    name: 'long.txt', text: longText, entities: [
      entity(longText, '陈明', 'APPLICANT'),
      entity(longText, '远航科技有限公司', 'ORGANIZATION'),
      entity(longText, '深圳市福田区深南大道100号', 'ADDRESS')
    ]
  },
  'zero.txt': {name: 'zero.txt', text: zeroText, entities: []},
  'repeated.txt': {
    name: 'repeated.txt', text: repeatedText, entities: [
      {type: 'PERSON', value: '张伟', start: repeatedFirst, end: repeatedFirst + 2, source: 'ner'},
      {type: 'PERSON', value: '张伟', start: repeatedSecond, end: repeatedSecond + 2, source: 'ner'},
      entity(repeatedText, '李娜', 'PERSON'),
      entity(repeatedText, '李娜', 'PERSON', 'ner', repeatedText.indexOf('李娜') + 1)
    ]
  },
  'roles.txt': {
    name: 'roles.txt', text: rolesText, entities: [
      entity(rolesText, '张伟', 'PLAINTIFF'),
      entity(rolesText, '张伟', 'PERSON'),
      entity(rolesText, '李娜', 'DEFENDANT'),
      entity(rolesText, '王强', 'ATTORNEY'),
      entity(rolesText, '海湾律师事务所', 'LAW_FIRM'),
      entity(rolesText, '深圳市南山区人民法院', 'COURT')
    ]
  }
};

export const SAMPLE_NAMES = Object.keys(FIXTURES);
