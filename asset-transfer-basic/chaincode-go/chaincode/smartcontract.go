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

func (s *SmartContract) verifySignature(hashHex string, signatureHex string, publicKeyPEM string) (bool, error) {
	block, _ := pem.Decode([]byte(publicKeyPEM))
	if block == nil {
		return false, fmt.Errorf("failed to parse PEM")
	}
	pubInterface, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return false, err
	}
	pubKey := pubInterface.(*ecdsa.PublicKey)

	sigBytes, _ := hex.DecodeString(signatureHex)
	r := new(big.Int).SetBytes(sigBytes[:len(sigBytes)/2])
	sVal := new(big.Int).SetBytes(sigBytes[len(sigBytes)/2:])

	hashBytes, _ := hex.DecodeString(hashHex)
	return ecdsa.Verify(pubKey, hashBytes, r, sVal), nil
}

func (s *SmartContract) IssueCertificate(ctx contractapi.TransactionContextInterface, id string, studentName string, major string, university string, issueDate string, grade string, issuerID string, signature string, publicKey string) error {
	// حساب SHA-3
	combinedData := fmt.Sprintf("%s%s%s%s", id, studentName, university, issueDate)
	hash := sha3.New256()
	hash.Write([]byte(combinedData))
	certHash := hex.EncodeToString(hash.Sum(nil))

	// التحقق المباشر
	isValid, err := s.verifySignature(certHash, signature, publicKey)
	if err != nil || !isValid {
		return fmt.Errorf("تنبيه أمني: التوقيع غير صالح")
	}

	cert := Certificate{
		ID: id, StudentName: studentName, Major: major, University: university,
		IssueDate: issueDate, Grade: grade, IssuerID: issuerID,
		CertHash: certHash, Signature: signature, PublicKey: publicKey,
	}
	certJSON, _ := json.Marshal(cert)
	return ctx.GetStub().PutState(id, certJSON)
}
