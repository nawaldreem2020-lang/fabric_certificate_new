package chaincode

import (
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"math/big"

	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
	"golang.org/x/crypto/sha3"
)

type SmartContract struct {
	contractapi.Contract
}

// Certificate المطور (تمت إضافة العلامات المائلة لضمان عمل الـ JSON بشكل صحيح)
type Certificate struct {
	ID          string `json:"ID"`
	StudentName string `json:"StudentName"`
	Major       string `json:"Major"`
	University  string `json:"University"`
	IssueDate   string `json:"IssueDate"`
	Grade       string `json:"Grade"`
	IssuerID    string `json:"IssuerID"`
	CertHash    string `json:"CertHash"`
	Signature   string `json:"Signature"`
	PublicKey   string `json:"PublicKey"`
}

// 1. دالة التحقق من التوقيع الرقمي (خوارزمية ECDSA - منهجية عمر سعد)
func (s *SmartContract) verifySignature(hash string, signatureHex string, publicKeyPEM string) (bool, error) {
	// أ. فك تشفير المفتاح العام من صيغة PEM
	block, _ := pem.Decode([]byte(publicKeyPEM))
	if block == nil {
		return false, fmt.Errorf("فشل في معالجة كتلة PEM للمفتاح العام")
	}

	pubInterface, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return false, fmt.Errorf("فشل في تحليل المفتاح العام: %v", err)
	}

	pubKey, ok := pubInterface.(*ecdsa.PublicKey)
	if !ok {
		return false, fmt.Errorf("المفتاح العام ليس من نوع ECDSA")
	}

	// ب. فك تشفير التوقيع من صيغة Hex
	sigBytes, err := hex.DecodeString(signatureHex)
	if err != nil {
		return false, fmt.Errorf("فشل في فك تشفير التوقيع من Hex: %v", err)
	}

	// ج. استخراج قيم R و S من التوقيع (تقسيم التوقيع لنصفين)
	r := new(big.Int).SetBytes(sigBytes[:len(sigBytes)/2])
	sVal := new(big.Int).SetBytes(sigBytes[len(sigBytes)/2:])

	// د. فك تشفير الهاش للمقارنة
	hashBytes, err := hex.DecodeString(hash)
	if err != nil {
		return false, err
	}

	// هـ. التحقق النهائي باستخدام خوارزمية ECDSA
	return ecdsa.Verify(pubKey, hashBytes, r, sVal), nil
}

// 2. دالة حساب SHA-3 (لضمان نزاهة البيانات)
func calculateSHA3Hash(data string) string {
	hash := sha3.New256()
	hash.Write([]byte(data))
	return hex.EncodeToString(hash.Sum(nil))
}

// 3. دالة إصدار الشهادة (تدمج الهاش والتوقيع معاً)
func (s *SmartContract) IssueCertificate(ctx contractapi.TransactionContextInterface, id string, studentName string, major string, university string, issueDate string, grade string, issuerID string, signature string, publicKey string) error {
	
	// حساب الهاش SHA-3 للبيانات الأساسية
	combinedData := fmt.Sprintf("%s%s%s%s", id, studentName, university, issueDate)
	certHash := calculateSHA3Hash(combinedData)

	// التحقق من التوقيع الرقمي قبل الحفظ (تطبيق منهجية عمر سعد)
	isValid, err := s.verifySignature(certHash, signature, publicKey)
	if err != nil || !isValid {
		return fmt.Errorf("تنبيه أمني: التوقيع الرقمي غير صالح، لا يمكن إصدار الشهادة")
	}

	cert := Certificate{
		ID:          id,
		StudentName: studentName,
		Major:       major,
		University:  university,
		IssueDate:   issueDate,
		Grade:       grade,
		IssuerID:    issuerID,
		CertHash:    certHash,
		Signature:   signature,
		PublicKey:   publicKey,
	}

	certJSON, err := json.Marshal(cert)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, certJSON)
}

// دالة التحقق من وجود الشهادة (تُستخدم داخلياً)
func (s *SmartContract) CertificateExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	certJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, err
	}
	return certJSON != nil, nil
}
