#!/bin/bash
set -e

# تعريف الألوان لسهولة القراءة
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 البدء في إعداد المشروع وتثبيت العقد الذكي المطور (SHA-3 + ECDSA)...${NC}"

# 1. إعداد المسارات الأساسية
if [ ! -d "bin" ]; then
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.9 1.5.7
fi
export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config/

# 2. تنظيف وإعادة تشغيل الشبكة
echo -e "${GREEN}🌐 الخطوة 1: تنظيف الحاويات وإعادة التشغيل...${NC}"
cd test-network
./network.sh down
./network.sh up createChannel -c mychannel -ca
cd ..

# 3. تهيئة مكتبات Go (حل خطأ الترجمة)
echo -e "${GREEN}📦 الخطوة 2: تهيئة مكتبات العقد الذكي...${NC}"
pushd asset-transfer-basic/chaincode-go
go mod tidy
go get golang.org/x/crypto/sha3
go mod vendor # لضمان وجود SHA-3 محلياً
popd

# 4. نشر العقد الذكي
echo -e "${GREEN}📜 الخطوة 3: نشر العقد الذكي 'basic'...${NC}"
cd test-network
./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go
sleep 15 # وقت استقرار الشبكة لمنع خطأ الاتصال
cd ..

# 5. تهيئة Caliper (حل Error Code 6)
echo -e "${GREEN}⚙️ الخطوة 4: تهيئة Caliper وربط SDK 2.2...${NC}"
cd caliper-workspace
npm install --only=prod
npx caliper bind --caliper-bind-sut fabric:2.2

# 6. تحديث ملف إعدادات الشبكة (تصحيح هيكل YAML)
echo "🔑 جلب المفتاح الخاص للـ Admin..."
KEY_DIR="../test-network/organizations/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp/keystore"
PVT_KEY=$(ls $KEY_DIR/*_sk | head -n 1)

# التعديل الهام: تصحيح المسافات (Indentation) في ملف YAML
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
      discover: false # تعطيل لمنع خطأ localhost
EOF

# 7. تنفيذ الاختبار الشامل (إضافة علامات الاستمرار '\')
echo -e "${GREEN}🚀 تشغيل اختبار Caliper المطور...${NC}"
npx caliper launch manager \
    --caliper-workspace . \
    --caliper-networkconfig networks/networkConfig.yaml \
    --caliper-benchconfig benchmarks/benchConfig.yaml \
    --caliper-flow-only-test

echo -e "${GREEN}🎉 تم الانتهاء بنجاح!${NC}"
