#!/bin/bash
set -e

# تعريف الألوان لسهولة القراءة في الـ Terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 البدء في إعداد المشروع وتثبيت العقد الذكي المطور (SHA-3 + ECDSA)...${NC}"
echo "=================================================="

# 1. إعداد المسارات الأساسية والأدوات
if [ ! -d "bin" ]; then
    echo "⬇️ Downloading Fabric binaries and Docker images (v2.5.9)..."
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.9 1.5.7
else
    echo "✅ Fabric tools found."
fi

export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config/

# 2. تنظيف شامل وإعادة تشغيل الشبكة (لضمان هوية جديدة للمنظمات)
echo -e "${GREEN}🌐 الخطوة 1: تنظيف الحاويات القديمة وإعادة التشغيل...${NC}"
cd test-network
./network.sh down
./network.sh up createChannel -c mychannel -ca
cd ..

# 3. تهيئة مكتبات Go (التعديل الجوهري لحل خطأ الترجمة)
echo -e "${GREEN}📦 الخطوة 2: تهيئة مكتبات العقد الذكي...${NC}"
pushd asset-transfer-basic/chaincode-go
# تنظيف الموديولات القديمة وجلب SHA-3
go mod tidy
go get golang.org/x/crypto/sha3
# إنشاء مجلد vendor لضمان وجود المكتبات أثناء النشر (يمنع فشل التثبيت)
go mod vendor 
popd

# 4. نشر العقد الذكي (basic)
echo -e "${GREEN}📜 الخطوة 3: نشر العقد الذكي 'basic'...${NC}"
cd test-network
./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go
echo "⏳ Waiting 15s for chaincode containers to stabilize..."
sleep 15 # وقت انتظار حيوي لضمان استقرار الشبكة قبل بدء Caliper
cd ..

# 5. تهيئة Caliper وربط المكتبات (لحل Error Code 6)
echo -e "${GREEN}⚙️ الخطوة 4: تهيئة Caliper وربط Fabric SDK 2.2...${NC}"
cd caliper-workspace
if [ ! -d "node_modules" ]; then
    npm install
fi
# الربط ضروري لتوافق Caliper مع إصدار الشبكة
npx caliper bind --caliper-bind-sut fabric:2.2

# 6. تحديث ملف إعدادات الشبكة (لحل مشكلة عدم تعريف المنظمات)
echo "🔑 جلب المفتاح الخاص الفعلي للـ Admin..."
KEY_DIR="../test-network/organizations/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp/keystore"
PVT_KEY=$(ls $KEY_DIR/*_sk | head -n 1) # جلب المسار الصحيح بدقة

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
      discover: false
EOF

# 7. تنفيذ الاختبار الشامل (50-200 TPS)
echo -e "${GREEN}🚀 تشغيل اختبار Caliper المطور...${NC}"
npx caliper launch manager \
    --caliper-workspace . \
    --caliper-networkconfig networks/networkConfig.yaml \
    --caliper-benchconfig benchmarks/benchConfig.yaml \
    --caliper-flow-only-test

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}🎉 تم الانتهاء! راجعي التقرير النهائي للنتائج.${NC}"
