#Region Public

// Removes an infobase prefix and a company prefix from the passed string ObjectNumber.
// The ObjectNumber variable should comply with template: OOGG-XXX...XX or GG-XXX...XX, where:
//    OO - a company prefix.
//    GG - an infobase prefix.
//    "-" - a separator.
//    XXX...XX - an object number/code.
// Insignificant prefix characters (zero - "0") are also removed.
//
// Parameters:
//    ObjectNumber - String - an object number or code from which prefixes are to be removed.
//    DeleteCompanyPrefix - Boolean - shows whether a company prefix is to be removed.
//                                         by default, it is equal to False.
//    DeleteInfobasePrefix - Boolean - shows whether an infobase prefix is to be removed.
//                                                by default, it is equal to False.
//
// Returns:
//     String - an object number without prefixes.
//
// Example:
//    DeletePrefixesFromObjectNumber("0FGL-000001234", True, True) = "000001234"
//    DeletePrefixesFromObjectNumber("0FGL-000001234", False, True) = "F-000001234"
//    DeletePrefixesFromObjectNumber("0FGL-000001234", True, False) = "GL-000001234"
//    DeletePrefixesFromObjectNumber("0FGL-000001234", False, False) = "FGL-000001234"
//
Function DeletePrefixesFromObjectNumber(Val ObjectNumber, DeleteCompanyPrefix = False, DeleteInfobasePrefix = False) Export
	
	If Not NumberContainsStandardPrefix(ObjectNumber) Then
		Return ObjectNumber;
	EndIf;
	
	// Initially blank string of object number prefix.
	ObjectPrefix = "";
	
	NumberContainsFiveDigitPrefix = NumberContainsFiveDigitPrefix(ObjectNumber);
	
	If NumberContainsFiveDigitPrefix Then
		CompanyPrefix        = Left(ObjectNumber, 2);
		InfobasePrefix = Mid(ObjectNumber, 3, 2);
	Else
		CompanyPrefix = "";
		InfobasePrefix = Left(ObjectNumber, 2);
	EndIf;
	
	CompanyPrefix        = StringFunctionsClientServer.DeleteDuplicateChars(CompanyPrefix, "0");
	InfobasePrefix = StringFunctionsClientServer.DeleteDuplicateChars(InfobasePrefix, "0");
	
	// Adding a company prefix.
	If Not DeleteCompanyPrefix Then
		
		ObjectPrefix = ObjectPrefix + CompanyPrefix;
		
	EndIf;
	
	// Adding an infobase prefix.
	If Not DeleteInfobasePrefix Then
		
		ObjectPrefix = ObjectPrefix + InfobasePrefix;
		
	EndIf;
	
	If Not IsBlankString(ObjectPrefix) Then
		
		ObjectPrefix = ObjectPrefix + "-";
		
	EndIf;
	
	Return ObjectPrefix + Mid(ObjectNumber, ?(NumberContainsFiveDigitPrefix, 6, 4));
EndFunction

// Removes leading zeros from the object number.
// The ObjectNumber variable should comply with template: OOGG-XXX...XX or GG-XXX...XX, where:
// OO - a company prefix.
// GG - an infobase prefix.
// "-" - a separator.
// XXX...XX - an object number/code.
//
// Parameters:
//    ObjectNumber - String - an object number or code from which leading zeroes are to be removed.
// 
// Returns:
//     String - an object number without leading zeros.
//
Function DeleteLeadingZerosFromObjectNumber(Val ObjectNumber) Export
	
	CustomPrefix = CustomPrefix(ObjectNumber);
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix = Left(ObjectNumber, 5);
			Number = Mid(ObjectNumber, 6 + StrLen(CustomPrefix));
		Else
			Prefix = Left(ObjectNumber, 3);
			Number = Mid(ObjectNumber, 4 + StrLen(CustomPrefix));
		EndIf;
		
	Else
		
		Prefix = "";
		Number = Mid(ObjectNumber, 1 + StrLen(CustomPrefix));
		
	EndIf;
	
	// Removing leading zeroes on the left from the number.
	Number = StringFunctionsClientServer.DeleteDuplicateChars(Number, "0");
	
	Return Prefix + CustomPrefix + Number;
EndFunction

// Removes all custom prefixes from the object number (all non-numeric characters).
// The ObjectNumber variable should comply with template: OOGG-XXX...XX or GG-XXX...XX, where:
// OO - a company prefix.
// GG - an infobase prefix.
// "-" - a separator.
// XXX...XX - an object number/code.
//
// Parameters:
//     ObjectNumber - String - an object number or code from which leading zeroes are to be removed.
// 
// Returns:
//     String - an object number without custom prefixes.
//
Function DeleteCustomPrefixesFromObjectNumber(Val ObjectNumber) Export
	
	NumericCharactersString = "0123456789";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix     = Left(ObjectNumber, 5);
			FullNumber = Mid(ObjectNumber, 6);
		Else
			Prefix     = Left(ObjectNumber, 3);
			FullNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	Else
		
		Prefix     = "";
		FullNumber = ObjectNumber;
		
	EndIf;
	
	Number = "";
	
	For Index = 1 To StrLen(FullNumber) Do
		
		Char = Mid(FullNumber, Index, 1);
		
		If StrFind(NumericCharactersString, Char) > 0 Then
			Number = Mid(FullNumber, Index);
			Break;
		EndIf;
		
	EndDo;
	
	Return Prefix + Number;
EndFunction

// Gets a custom object number/code prefix.
// The ObjectNumber variable should comply with template: OOGG-XXX...XX or GG-XXX...XX, where:
// OO - a company prefix.
// GG - an infobase prefix.
// "-" - a separator.
// AA - a custom prefix.
// XX...XX - an object number/code.
//
// Parameters:
//    ObjectNumber - String - an object number or object code from which a custom prefix is to be received.
// 
// Returns:
//     String - a custom prefix.
//
Function CustomPrefix(Val ObjectNumber) Export
	
	// Function return value (custom prefix).
	Result = "";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			ObjectNumber = Mid(ObjectNumber, 6);
		Else
			ObjectNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	EndIf;
	
	NumericCharactersString = "0123456789";
	
	For Index = 1 To StrLen(ObjectNumber) Do
		
		Char = Mid(ObjectNumber, Index, 1);
		
		If StrFind(NumericCharactersString, Char) > 0 Then
			Break;
		EndIf;
		
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
EndFunction

// Gets a document number for printing, prefixes and leading zeros are removed from the number.
// Function:
// discards a company prefix, discards an infobase prefix (optional), discards custom prefixes 
// (optional), removes leading zeros from the object number.
// 
// 
//
// Parameters:
//    ObjectNumber - String - an object number or code that is converted for printing.
//    DeleteInfobasePrefix - Boolean - shows whether an infobase prefix is to be removed.
//    DeleteCustomPrefix - Boolean - shows whether a custom prefix is to be removed.
//
// Returns:
//     String - a number for printing.
//
Function NumberForPrinting(Val ObjectNumber, DeleteInfobasePrefix = False, DeleteCustomPrefix = False) Export
	
	// {Handler: OnGetNumberForPrinting} Start
	StandardProcessing = True;
	
	ObjectsPrefixesClientServerOverridable.OnGetNumberForPrinting(ObjectNumber, StandardProcessing,
		DeleteInfobasePrefix, DeleteCustomPrefix);
	
	If StandardProcessing = False Then
		Return ObjectNumber;
	EndIf;
	// {Handler: OnGetNumberForPrinting} End
	
	ObjectNumber = TrimAll(ObjectNumber);
	
	// Removing custom prefixes from the object number.
	If DeleteCustomPrefix Then
		
		ObjectNumber = DeleteCustomPrefixesFromObjectNumber(ObjectNumber);
		
	EndIf;
	
	// Removing leading zeros from the object number.
	ObjectNumber = DeleteLeadingZerosFromObjectNumber(ObjectNumber);
	
	// Removing a company prefix and an infobase prefix from the object number.
	ObjectNumber = DeletePrefixesFromObjectNumber(ObjectNumber, True, DeleteInfobasePrefix);
	
	Return ObjectNumber;
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use CustomPrefix.
// Gets a custom object number/code prefix.
// The ObjectNumber variable should comply with template: OOGG-XXX...XX or GG-XXX...XX, where:
// OO - a company prefix.
// GG - an infobase prefix.
// "-" - a separator.
// AA - a custom prefix.
// XX...XX - an object number/code.
//
// Parameters:
//    ObjectNumber - String - an object number or object code from which a custom prefix is to be received.
// 
// Returns:
//     String - a custom prefix.
//
Function GetCustomPrefix(Val ObjectNumber) Export
	Return CustomPrefix(ObjectNumber);
EndFunction

// Obsolete. Use NumberForPrinting.
// Gets a document number for printing, prefixes and leading zeros are removed from the number.
// Function:
// discards a company prefix, discards an infobase prefix (optional), discards custom prefixes 
// (optional), removes leading zeros from the object number.
// 
// 
//
// Parameters:
//    ObjectNumber - String - an object number or code that is converted for printing.
//    DeleteInfobasePrefix - Boolean - shows whether an infobase prefix is to be removed.
//    DeleteCustomPrefix - Boolean - shows whether a custom prefix is to be removed.
//
// Returns:
//     String - a number for printing.
//
Function GetNumberForPrinting(Val ObjectNumber, DeleteInfobasePrefix = False, DeleteCustomPrefix = False) Export
	Return NumberForPrinting(ObjectNumber, DeleteInfobasePrefix, DeleteCustomPrefix);
EndFunction

#EndRegion

#EndRegion

#Region Private

Function NumberContainsStandardPrefix(Val ObjectNumber)
	
	SeparatorPosition = StrFind(ObjectNumber, "-");
	
	Return (SeparatorPosition = 3 Or SeparatorPosition = 5);
	
EndFunction

Function NumberContainsFiveDigitPrefix(Val ObjectNumber)
	
	Return StrFind(ObjectNumber, "-") = 5;
	
EndFunction

#EndRegion
