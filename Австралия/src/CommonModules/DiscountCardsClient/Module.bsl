
#Region Public

Function GetDiscountCardInapplicableMessage() Export 
	
	Return NStr("en = 'The discount card is inapplicable. Its owner does not match the counterparty specified in the document.'; ru = 'Дисконтная карта неприменима. Ее владелец не соответствует контрагенту, указанному в документе.';pl = 'Karta rabatowa nie może być zastosowana. Jej właściciel różni się od kontrahenta, określonego w dokumencie.';es_ES = 'La tarjeta de descuento no es aplicable. Su propietario no coincide con la contraparte especificada en el documento.';es_CO = 'La tarjeta de descuento no es aplicable. Su propietario no coincide con la contraparte especificada en el documento.';tr = 'İndirim kartı uygulanamıyor. Sahibi, belgede belirtilen cari hesap ile eşleşmiyor.';it = 'La carta sconto non è valida. Il titolare della carta non corrisponde alla controparte indicata nel documento.';de = 'Die Rabattkarte ist nicht anwendbar. Deren Inhaber stimmt mit dem im Dokument bezeichneten Geschäftspartner nicht überein.'");
	
EndFunction

#EndRegion

#Region WorkMethodsWithBarcodeScanner

///////////////////////////////////////////////////
// THE METHODS OF WORK WITH THE BAOCRDE SCANNER

Function ConvertDataFromScannerIntoArray(Parameter) Export 

  Data = New Array;
	Data.Add(ConvertDataFromScannerIntoStructure(Parameter));
	
	Return Data;
	
EndFunction

Function ConvertDataFromScannerIntoStructure(Parameter) Export
	
	If Parameter[1] = Undefined Then
		Data = New Structure("Barcode, Quantity", Parameter[0], 1); 	 // Get a barcode from the basic data
	Else
		Data = New Structure("Barcode, Quantity", Parameter[1][1], 1); // Get a barcode from the additional data
	EndIf;
	
	Return Data;
	
EndFunction

#EndRegion
