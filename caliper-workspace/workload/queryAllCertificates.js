'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

/**
 * فئة عبء العمل للاستعلام عن الشهادات باستخدام تقنية التقسيم (Pagination).
 * تم تطوير هذا الملف لحل مشكلة Timeout التي ظهرت في التقرير السابق عند 100 TPS.
 */
class QueryAllCertificatesWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        // يمكن إضافة متغيرات هنا إذا كنت ترغب في تتبع العلامة المرجعية (bookmark)
    }

    /**
    * إرسال طلب استعلام مقسم لضمان استقرار الشبكة وكفاءة استرجاع بيانات SHA-3.
    */
    async submitTransaction() {
        const request = {
            contractId: 'basic',
            // التعديل 1: استخدام اسم الدالة الجديدة في العقد الذكي التي تدعم Pagination
            contractFunction: 'GetAllAssetsWithPagination', 
            
            // التعديل 2: إرسال المعاملات المطلوبة (pageSize و bookmark)
            // نحدد pageSize بـ '50' لتقليل حجم البيانات المسترجعة في كل طلب ومنع انهيار الذاكرة
            contractArguments: ['30', ''], 
            
            readOnly: true
        };

        // إرسال الطلب عبر محول النظام تحت الاختبار (SUT Adapter)
        await this.sutAdapter.sendRequests(request);
    }
}

/**
 * دالة المصنع لإنشاء وحدة عبء العمل.
 */
function createWorkloadModule() {
    return new QueryAllCertificatesWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
