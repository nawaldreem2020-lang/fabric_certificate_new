package chaincode

import (
	"crypto/ecdsa"
	"crypto/sha256"
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

// Certificate المطور ليشمل منطق التوقيع (منهجية عمر سعد)
type Certificate struct {
	ID          string `json:"ID"`
	StudentName string `json:"StudentName"`
	Major       string `json:"Major"`
	University  string `json:"University"`
	IssueDate   string `json:"IssueDate"`
	Grade       string `json:"Grade"`
	IssuerID    string `json:"IssuerID"`
	CertHash    string `json:"CertHash"`
	Signature   string `json:"Signature"` // التوقيع الرقمي المولد خارجياً (من المصدر)
	PublicKey   string `json:"PublicKey"` // المفتاح العام للتحقق من المصدر
}

// دالة التحقق من التوقيع الرقمي (خوارزمية ECDSA)
func (s *SmartContract) verifySignature(hash string, signatureHex string, publicKeyPEM string) (bool, error) {
	// 1. فك تشفير المفتاح العام من صيغة PEM
	block, _ := pem.Decode([]byte(publicKeyPEM))
	if block == nil {
		return false, fmt.Errorf("failed to parse PEM block containing the public key")
	}
	pubInterface, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return false, err
	}
	pubKey := pubInterface.(*ecdsa.PublicKey)

	// 2. فك تشفير التوقيع من Hex
	sigBytes, _ := hex.DecodeString(signatureHex)
	
	// فك التوقيع إلى R و S (أجزاء توقيع ECDSA)
	r := new(big.Int).SetBytes(sigBytes[:len(sigBytes)/2])
	sVal := new(big.Int).SetBytes(sigBytes[len(sigBytes)/2:])

	// 3. التحقق الفعلي
	hashBytes, _ := hex.DecodeString(hash)
	return ecdsa.Verify(pubKey, hashBytes, r, sVal), nil
}

// IssueCertificate: معدلة للتحقق من التوقيع قبل الحفظ
func (s *SmartContract) IssueCertificate(ctx contractapi.TransactionContextInterface, id string, studentName string, major string, university string, issueDate string, grade string, issuerID string, signature string, publicKey string) error {
	
	// حساب الهاش الأصلي للبيانات
	combinedData := fmt.Sprintf("%s%s%s%s", id, studentName, university, issueDate)
	certHash := calculateSHA3Hash(combinedData)

	// تطبيق خوارزمية عمر سعد: التحقق من أن التوقيع يخص هذه البيانات والمفتاح العام
	isValid, err := s.verifySignature(certHash, signature, publicKey)
	if err != nil || !isValid {
		return fmt.Errorf("فشل التحقق من التوقيع الرقمي: الشهادة غير موثوقة المصدر")
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

// دالة الهاش SHA-3 المستمرة في العمل للنزاهة
func calculateSHA3Hash(data string) string {
	hash := sha3.New256()
	hash.Write([]byte(data))
	return hex.EncodeToString(hash.Sum(nil))
}

// ... بقية الدوال (Verify, Delete, Pagination) تبقى كما هي مع تحديث Struct الشهادة ...
