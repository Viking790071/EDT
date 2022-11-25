#Region Public

// Divides the individual full name into its constituent parts: last name, name and patronymic.
// If a full name has ogly, uly, uulu, qizy, or gizi in the end, they are also a part of patronymic.
// 
//
// Parameters:
//  FullNameWithPatronymic - String - a full name as Last name Name Patronymic.
//
// Returns:
//  Structure - full name parts:
//   * LastName  - String - last name.
//   * Name - String - a name.
//   * Patronymic - String - a patronymic.
//
// Example:
//   1. IndividualsClientServer.NameParts("Ivanov Ivan Ivanovich") will return a structure with the 
//   following property values: "Ivanov", "Ivan", "Ivanovich".
//   2. IndividualsClientServer.NameParts("Smith John") will return a structure with the following 
//   property values: "Smith", "John", "".
//   3. IndividualsClientServer.NameParts("Aliev Achmed Oktay ogly Mamedov") will return a structure 
//   with the property values: "Aliev", "Aliev", "Oktay ogly Mamedov".
//
Function NameParts(FullNameWithPatronymic) Export
	
	Result = New Structure("LastName,Name,Patronymic");
	
	NameParts = StrSplit(FullNameWithPatronymic, " ", False);
	
	If NameParts.Count() >= 1 Then
		Result.LastName = NameParts[0];
	EndIf;
	
	If NameParts.Count() >= 2 Then
		Result.Name = NameParts[1];
	EndIf;
	
	If NameParts.Count() >= 3 Then
		Result.Patronymic = NameParts[2];
	EndIf;
	
	If NameParts.Count() > 3 Then
		MiddleNameAdditionalParts = New Array;
		MiddleNameAdditionalParts.Add(NStr("ru = 'оглы'; en = 'ogly'; pl = 'ogly';es_ES = 'ogly';es_CO = 'ogly';tr = 'oğlu';it = 'ogly';de = 'ogly'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'улы'; en = 'uly'; pl = 'uly';es_ES = 'uly';es_CO = 'uly';tr = 'uly';it = 'luglio';de = 'uly'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'уулу'; en = 'uulu'; pl = 'uulu';es_ES = 'uulu';es_CO = 'uulu';tr = 'uulu';it = 'Uulu';de = 'uulu'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'кызы'; en = 'kizi'; pl = 'qizy';es_ES = 'kizi';es_CO = 'kizi';tr = 'kızı';it = 'kizi';de = 'qizy'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'гызы'; en = 'gizi'; pl = 'gizi';es_ES = 'gizi';es_CO = 'gizi';tr = 'gizi';it = 'gizi';de = 'gizi'"));
		
		If MiddleNameAdditionalParts.Find(Lower(NameParts[3])) <> Undefined Then
			Result.Patronymic = Result.Patronymic + " " + NameParts[3];
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Generates a short presentation of the individual full name.
//
// Parameters:
//  FullNameWithPatronymic - String - a full name as Last name Name Patronymic.
//                     - Structure - full name parts:
//                        * LastName  - String - last name.
//                        * Name - String - a name.
//                        * Patronymic - String - a patronymic.
//
// Returns:
//  String - last name and initials. For example, "Smith J. AND.".
//
// Example:
//  Result = IndividualsClientServer.IndividualShortName("John Smith");
//  - Returns "Smith J. AND.".
//
Function InitialsAndLastName(Val FullNameWithPatronymic) Export
	
	If TypeOf(FullNameWithPatronymic) = Type("String") Then
		FullNameWithPatronymic = NameParts(FullNameWithPatronymic);
	EndIf;
	
	LastName = FullNameWithPatronymic.LastName;
	Name = FullNameWithPatronymic.Name;
	Patronymic = FullNameWithPatronymic.Patronymic;
	
	If IsBlankString(Name) Then
		Return LastName;
	EndIf;
	
	If IsBlankString(Patronymic) Then
		Return StringFunctionsClientServer.SubstituteParametersToString("%1 %2.", LastName, Left(Name, 1));
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString("%1 %2.%3.", LastName, Left(Name, 1), Left(Patronymic, 1));
	
EndFunction

// Checks whether the full name of individual is written correctly.
// Full name is considered to be correct if it contains either cyrillic letters, or latin letters only.
//
// Parameters:
//  FullName - String - last name, name, and patronymic. For example, John Smith.
//  OnlyRoman - Boolean - only cyrillic alphabet is allowed in full name on check.
//
// Returns:
//  Boolean - True if the full name is written correctly.
//
Function FullNameWrittenCorrectly(Val FullName, OnlyRoman = False) Export
	
	AllowedChars = "-";
	
	Return (Not OnlyRoman AND StringFunctionsClientServer.OnlyRomanInString(FullName, False, AllowedChars))
		Or StringFunctionsClientServer.OnlyLatinInString(FullName, False, AllowedChars);
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. use NameParts instead.
//
// Splits the full name string into a structure.
//
// Parameters:
//  FullName - String - description.
//
// Returns:
//  Structure - last, first, and patronymic names:
//   * LastName  - String - last name.
//   * Name - String - a name.
//   * Patronymic - String - a patronymic.
//
Function FullNameWithPatronymic(Val FullName) Export
	
	FullNameStructure = New Structure("LastName, Name, Patronymic");
	
	SubstringsArray = StrSplit(FullName, " ", False);
	
	If SubstringsArray.Count() > 0 Then
		FullNameStructure.Insert("LastName", SubstringsArray[0]);
		If SubstringsArray.Count() > 1 Then
			FullNameStructure.Insert("Name", SubstringsArray[1]);
		EndIf;
		If SubstringsArray.Count() > 2 Then
			Patronymic = "";
			For Step = 2 To SubstringsArray.Count()-1 Do
				Patronymic = Patronymic + SubstringsArray[Step] + " ";
			EndDo;
			StringFunctionsClientServer.DeleteLastCharInString(Patronymic, 1);
			FullNameStructure.Insert("Patronymic", Patronymic);
		EndIf;
	EndIf;
	
	Return FullNameStructure;
	
EndFunction

// Obsolete. Use InitialsAndLastName and NameParts instead.
// Generates the initials and last name by the passed strings.
//
// Parameters:
//  FullNameAsString	- String - if this parameter is specified, other parameters are ignored.
//  LastName		- String - last name of an individual.
//  FirstName			- String - first name of an individual.
//  Patronymic	- String - patronymic of an individual.
//
// Returns:
//  String - initials and last name in one string.
//  Calculated parts are written to LastName, Name, and Patronymic parameters.
//
// Example:
//  Result = IndividualShortName("John Smith"); // Result = J. Smith. AND."
//
Function IndividualShortName(FullNameString = "", LastName = " ", Name = " ", Patronymic = " ") Export

	ObjectType = TypeOf(FullNameString);
	If ObjectType = Type("String") Then
		FullName = StrSplit(FullNameString, " ", False);
	Else
		// Using separate parameters.
		Return ?(Not IsBlankString(LastName), 
		          LastName + ?(Not IsBlankString(Name), " " + Left(Name,1) + "." + ?(Not IsBlankString(Patronymic), Left(Patronymic,1) + ".", ""), ""),
		          "");
	EndIf;
	
	SubstringCount = FullName.Count();
	LastName            = ?(SubstringCount > 0, FullName[0], "");
	Name                = ?(SubstringCount > 1, FullName[1], "");
	Patronymic           = ?(SubstringCount > 2, FullName[2], "");
	
	If SubstringCount > 3 Then
		MiddleNameAdditionalParts = New Array;
		MiddleNameAdditionalParts.Add(NStr("ru = 'оглы'; en = 'ogly'; pl = 'ogly';es_ES = 'ogly';es_CO = 'ogly';tr = 'oğlu';it = 'ogly';de = 'ogly'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'улы'; en = 'uly'; pl = 'uly';es_ES = 'uly';es_CO = 'uly';tr = 'uly';it = 'luglio';de = 'uly'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'уулу'; en = 'uulu'; pl = 'uulu';es_ES = 'uulu';es_CO = 'uulu';tr = 'uulu';it = 'Uulu';de = 'uulu'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'кызы'; en = 'kizi'; pl = 'qizy';es_ES = 'kizi';es_CO = 'kizi';tr = 'kızı';it = 'kizi';de = 'qizy'"));
		MiddleNameAdditionalParts.Add(NStr("ru = 'гызы'; en = 'gizi'; pl = 'gizi';es_ES = 'gizi';es_CO = 'gizi';tr = 'gizi';it = 'gizi';de = 'gizi'"));
		
		If MiddleNameAdditionalParts.Find(Lower(FullName[3])) <> Undefined Then
			Patronymic = Patronymic + " " + FullName[3];
		EndIf;
	EndIf;
	
	Return ?(Not IsBlankString(LastName), 
	          LastName + ?(Not IsBlankString(Name), " " + Left(Name, 1) + "." + ?(Not IsBlankString(Patronymic), Left(Patronymic, 1) + ".", ""), ""),
	          "");
	
EndFunction

#EndRegion

#EndRegion
