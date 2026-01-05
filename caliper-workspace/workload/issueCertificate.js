'use strict';
const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
const crypto = require('crypto');

class IssueCertificateWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        // توليد مفاتيح ECDSA (المنحنى P-256)
        const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', {
            namedCurve: 'P-256',
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

        // 1. حساب الهاش SHA-3 (المنطقي الوحيد)
        const combinedData = `${certID}${studentName}${university}${issueDate}`;
        const hash = crypto.createHash('sha3-256').update(combinedData).digest();

        // 2. التوقيع المباشر على هاش SHA-3 (بدون خلط مع SHA-256)
        // نستخدم dsaEncoding: 'ieee-p1363' للحصول على R+S متصلين مباشرة كما يتوقع كود Go
        const signature = crypto.sign(null, hash, {
            key: this.privateKey,
            dsaEncoding: 'ieee-p1363' 
        }).toString('hex');

        const request = {
            contractId: 'basic',
            contractFunction: 'IssueCertificate',
            contractArguments: [
                certID, studentName, 'Computer Science', university, 
                issueDate, 'Excellent', 'Admin_01', signature, this.publicKey
            ],
            readOnly: false
        };

        await this.sutAdapter.sendRequests(request);
    }
}
module.exports = IssueCertificateWorkload;
