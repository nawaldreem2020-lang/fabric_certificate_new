'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
const crypto = require('crypto'); // مكتبة التشفير المدمجة في Node.js

class IssueCertificateWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        // توليد مفاتيح الجامعة (مرة واحدة لكل Worker لتقليل استهلاك الـ CPU)
        const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', {
            namedCurve: 'P-256', // المنحنى الإهليلجي المستخدم في Fabric
            publicKeyEncoding: { type: 'spki', format: 'pem' },
            privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
        });
        this.privateKey = privateKey;
        this.publicKey = publicKey;
    }

    async submitTransaction() {
        this.txIndex++;
        const certID = `cert_${this.workerIndex}_${this.txIndex}`;
        const studentName = 'Student ' + this.txIndex;
        const university = 'University of Sanaa';
        const issueDate = '2025-12-28';

        // 1. حساب الهاش SHA-3 (نفس المنطق الموجود في العقد الذكي)
        const combinedData = `${certID}${studentName}${university}${issueDate}`;
        const hash = crypto.createHash('sha3-256').update(combinedData).digest();
        const hashHex = hash.toString('hex');

        // 2. توليد التوقيع الرقمي (Signature) باستخدام المفتاح الخاص
        const sign = crypto.createSign('SHA256');
        sign.update(hash);
        sign.end();
        // تحويل التوقيع إلى صيغة Hex (عمر سعد يستخدم R+S concatenated)
        const signature = sign.sign(this.privateKey).toString('hex');

        const request = {
            contractId: 'basic',
            contractFunction: 'IssueCertificate',
            contractArguments: [
                certID,
                studentName,
                'Computer Science',
                university,
                issueDate,
                'Excellent',
                'Admin_01',
                signature,      // التوقيع الرقمي الجديد
                this.publicKey  // المفتاح العام للتحقق
            ],
            readOnly: false
        };

        await this.sutAdapter.sendRequests(request);
    }
}

module.exports = IssueCertificateWorkload;
