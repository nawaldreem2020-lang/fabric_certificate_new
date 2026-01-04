#!/bin/bash
set -e

# تعريف الألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 البدء في إعداد المشروع وتثبيت العقد الذكي المطور (SHA-3 + ECDSA)...${NC}"
echo "=================================================="

# التأكد من وجود الأدوات الأساسية
if [ ! -d "bin" ]; then
    echo "⬇️ Downloading Fabric binaries and Docker images (v2.5.9)..."
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.9 1.5.7
else
    echo "✅ Fabric tools found."
fi

export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config/

# 1. تنظيف شامل وإعادة تشغيل الشبكة
echo -e "${GREEN}🌐 الخطوة 1: تنظيف الحاويات القديمة وإعادة التشغيل...${NC}"
cd test-network
./network.sh down
./network.sh up createChannel -c mychannel -ca
cd ..

# 2. تحديث مكتبات Go (تعديل لضمان استقرار الـ Vendor)
echo -e "${GREEN}📦 الخطوة 2: تهيئة مكتبات SHA-3 في العقد الذكي...${NC}"
pushd asset-transfer-basic/chaincode-go
go mod tidy
go mod vendor # إضافة هامة لضمان توفر المكتبات أثناء النشر
popd

# 3. نشر العقد الذكي (تعديل: إضافة وقت انتظار للمزامنة)
echo -e "${GREEN}📜 الخطوة 3: نشر العقد الذكي 'basic'...${NC}"
cd test-network
./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go
echo "⏳ Waiting for chaincode containers to stabilize..."
sleep 15 # وقت إضافي لمنع Error Code 6 عند البدء الفوري
cd ..

# 4. تهيئة Caliper (تعديل: التأكد من الربط الصحيح لـ SDK)
echo -e "${GREEN}⚙️ الخطوة 4: ربط Caliper بـ Fabric SDK 2.2...${NC}"
cd caliper-workspace
npm install --only=prod
npx caliper bind --caliper-bind-sut fabric:2.2

# 5. تحديث ملف إعدادات الشبكة (تعديل: إصلاح مسارات الهوية)
echo "🔑 جلب المفتاح الخاص الفعلي للـ Admin..."
KEY_DIR="../test-network/organizations/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp/keystore"
PVT_KEY=$(ls $KEY_DIR/*_sk | head -n 1) # اختيار أول مفتاح موجود

cat << EOF > networks/networkConfig.yaml
name: Caliper-Fabric
version: "2.0.0"
caliper:
  blockchain: fabric
channels:
  - channelName: mychannel
    contracts:
      - id: basic
organizations:
  - mspid: Org1MSP
    identities:
      certificates:
        - name: 'User1'
          clientPrivateKey:
            path: '$PVT_KEY'
          clientSignedCert:
            path: '../test-network/organizations/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp/signcerts/cert.pem'
    connectionProfile:
      path: '../test-network/organizations/peerOrganizations/org1.example.com/connection-org1.yaml'
      discover: true
EOF

# 6. تنفيذ الاختبار (تعديل: استخدام الملف الشامل الجديد)
echo -e "${GREEN}🚀 تشغيل اختبار Caliper الشامل (50-200 TPS)...${NC}"
npx caliper launch manager \
    --caliper-workspace . \
    --caliper-networkconfig networks/networkConfig.yaml \
    --caliper-benchconfig benchmarks/benchConfig.yaml \
    --caliper-flow-only-test

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}🎉 تم الانتهاء! راجعي ملف التحليل في مجلد التابع لـ Caliper.${NC}"
