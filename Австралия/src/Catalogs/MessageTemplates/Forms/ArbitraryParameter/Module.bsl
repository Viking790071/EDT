///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.TypeDetails.Types().Count() > 0 Then
		FoundParameterType = Parameters.TypeDetails.Types()[0];
	EndIf;
	
	FillChoiceListInputOnBasis(FoundParameterType);
	
	For each ParameterFromForm In Parameters.ParametersList Do
		If StrStartsWith(Parameters.ParameterName, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
			ParameterNameToCheck = Mid(Parameters.ParameterName, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2);
		Else
			ParameterNameToCheck = Parameters.ParameterName;
		EndIf;
		If ParameterFromForm.ParameterName = ParameterNameToCheck Then
			Continue;
		EndIf;
		ParametersList.Add(ParameterFromForm.ParameterName, ParameterFromForm.ParameterPresentation);
	EndDo;
	
	If StrStartsWith(Parameters.ParameterName, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
		ParameterName = Mid(Parameters.ParameterName, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2);
	Else
		ParameterName = Parameters.ParameterName;
	EndIf;
	ParameterPresentation = Parameters.ParameterPresentation;
	ParameterType = Parameters.TypeDetails;
	
EndProcedure

&AtServerNoContext
Function ParameterTypeAsString(FullTypeName)
	
	If StrCompare(FullTypeName, "Date") = 0 Then
		Result = Type("Date");
	ElsIf StrCompare(FullTypeName, "String") = 0 Then
		Result = Type("String");
	Else
		ObjectManager = Common.ObjectManagerByFullName(FullTypeName);
		If ObjectManager <> Undefined Then
			Result = TypeOf(ObjectManager.EmptyRef());
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParameterTypeOnChange(Item)
	If IsBlankString(ParameterPresentation) AND IsBlankString(ParameterName) Then
		ParameterPresentation = Items.TypeString.EditText;
		Position = StrFind(TypeString, ".", SearchDirection.FromEnd);
		If Position > 0 AND Position < StrLen(TypeString) Then
			ParameterName = Mid(TypeString, Position + 1);
		Else
			ParameterName = TypeString;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	For Each ParameterFromForm In ParametersList Do
		If StrCompare(ParameterFromForm.Value, ParameterName) = 0 Then
			ShowMessageBox(, NStr("ru = '???????????????????????? ?????? ??????????????????. ???????????????? ?? ?????????? ???????????? ?????? ?????? ???????????????? ??????????.'; en = 'Placeholder name error. A placeholder with this name already exists.'; pl = 'B????d nazwy symbolu zast??pczego. Symbol zast??pczy o tej nazwie ju?? istnieje.';es_ES = 'Error en el nombre del marcador de posici??n. Ya existe un marcador de posici??n con este nombre.';es_CO = 'Error en el nombre del marcador de posici??n. Ya existe un marcador de posici??n con este nombre.';tr = 'Yer tutucu ad?? hatas??. Bu ada sahip bir yer tutucu zaten var.';it = 'Errore nome segnaposto. Esiste gi?? un segnaposto con questo nome.';de = 'Fehler des Platzhalternamens. Es existiert bereits ein Platzhalter mit diesem Namen.'"));
			Return;
		EndIf;
		If StrCompare(ParameterFromForm.Presentation, ParameterPresentation) = 0 Then
			ShowMessageBox(, NStr("ru = '???????????????????????? ?????????????????????????? ??????????????????. ???????????????? ?? ?????????? ???????????????????????????? ?????? ?????? ???????????????? ??????????.'; en = 'Placeholder presentation error. A placeholder with this presentation already exists.'; pl = 'B????d prezentacji symbolu zast??pczego. symbol zast??pczy z t?? prezentacj?? ju?? istnieje.';es_ES = 'Error de presentaci??n del marcador de posici??n. Ya existe un marcador de posici??n con esta presentaci??n.';es_CO = 'Error de presentaci??n del marcador de posici??n. Ya existe un marcador de posici??n con esta presentaci??n.';tr = 'Yer tutucu sunum hatas??. Bu sunuma sahip bir yer tutucu zaten mevcut.';it = 'Errore di presentazione del segnaposto. Esiste gi?? un segnaposto con questa presentazione.';de = 'Fehler bei der Pr??sentation des Platzhalters. Es existiert bereits ein Platzhalter mit dieser Pr??sentation.'"));
			Return;
		EndIf;
	EndDo;
	
	If InvalidParameterName(ParameterName) OR IsBlankString(ParameterName) Then
		ShowMessageBox(, NStr("ru = '???????????????????????? ?????? ??????????????????. ???????????? ???????????????????????? ??????????????, ?????????? ???????????????????? ?? ???????????? ????????. ??????????????.'; en = 'Invalid placeholder name. Special characters and whitespace are not allowed.'; pl = 'Nieprawid??owa nazwa symbolu zast??pczego. Znaki specjalne i spacje nie s?? dozwolone.';es_ES = 'Nombre de marcador de posici??n inv??lido. No se permiten caracteres especiales ni espacios en blanco.';es_CO = 'Nombre de marcador de posici??n inv??lido. No se permiten caracteres especiales ni espacios en blanco.';tr = 'Ge??ersiz yer tutucu ad??. ??zel karakterler ve bo??luk kullan??lamaz.';it = 'Nome segnaposto non valido. Caratteri speciali e spazi non sono ammessi.';de = 'Ung??ltiger Platzhaltername. Sonderzeichen und Leerraum sind nicht erlaubt.'"));
		Return;
	EndIf;
	
	If IsBlankString(ParameterPresentation) Then
		ShowMessageBox(, NStr("ru = '???????????????????????? ?????????????????????????? ??????????????????.'; en = 'Invalid placeholder presentation.'; pl = 'Nieprawid??owa prezentacja symbolu zast??pczego.';es_ES = 'Presentaci??n de marcador de posici??n no v??lida.';es_CO = 'Presentaci??n de marcador de posici??n no v??lida.';tr = 'Ge??ersiz yer tutucu sunumu.';it = 'Presentazione segnaposto non valida.';de = 'Ung??ltige Platzhalterpr??sentation.'"));
		Return;
	EndIf;
	
	If IsBlankString(TypeString) Then
		ShowMessageBox(, NStr("ru = '???????????????????????? ?????? ??????????????????.'; en = 'Invalid placeholder type.'; pl = 'Niepoprawny typ symbolu zast??pczego.';es_ES = 'Tipo de marcador de posici??n no v??lido.';es_CO = 'Tipo de marcador de posici??n no v??lido.';tr = 'Ge??ersiz yer tutucu t??r??.';it = 'Tipo di segnaposto non valido.';de = 'Ung??ltiger Platzhalter-Typ.'"));
		Return;
	EndIf;
	
	Result = New Structure("ParameterName, ParameterPresentation, ParameterType");
	FillPropertyValues(Result, ThisObject);
	Result.ParameterType = ParameterTypeAsString(TypeString);
	Close(Result);
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close(Undefined);
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function InvalidParameterName(ParameterName)
	
	Try
		Test = New Structure(ParameterName, ParameterName);
	Except
		Return True;
	EndTry;
	
	Return TypeOf(Test) <> Type("Structure");
	
EndFunction

&AtServer
Procedure FillChoiceListInputOnBasis(ParameterType)
	
	TypePresentation = "";
	MessagesTemplatesSettings = MessagesTemplatesInternalCachedModules.OnDefineSettings();
	For each TemplateSubject In MessagesTemplatesSettings.TemplateSubjects Do
		If StrCompare(TemplateSubject.Name, Parameters.InputOnBasisParameterTypeFullName) = 0 Then
			Continue;
		EndIf;
		ObjectMetadata = Metadata.FindByFullName(TemplateSubject.Name);
		If ObjectMetadata = Undefined Then
			Continue;
		EndIf;
		Items.TypeString.ChoiceList.Add(TemplateSubject.Name, TemplateSubject.Presentation);
		
		ObjectManager = Common.ObjectManagerByFullName(TemplateSubject.Name);
		If ObjectManager <> Undefined Then
			If ParameterType = TypeOf(ObjectManager.EmptyRef()) Then
				TypePresentation = TemplateSubject.Name;
			EndIf;
		EndIf;
	EndDo;
	
	If ParameterType = Type("String") Then
		TypePresentation = NStr("ru = '????????????'; en = 'String'; pl = 'Wiersz';es_ES = 'L??nea';es_CO = 'L??nea';tr = 'Dize';it = 'Riga';de = 'Zeichenfolge'");
	ElsIf ParameterType = Type("Date") Then
		TypePresentation = NStr("ru = '????????'; en = 'Date'; pl = 'Data';es_ES = 'Fecha';es_CO = 'Fecha';tr = 'Tarih';it = 'Data';de = 'Datum'");
	EndIf;
	
	Items.TypeString.ChoiceList.Insert(0, "Date", NStr("ru = '????????'; en = 'Date'; pl = 'Data';es_ES = 'Fecha';es_CO = 'Fecha';tr = 'Tarih';it = 'Data';de = 'Datum'"));
	Items.TypeString.ChoiceList.Insert(0, "String", NStr("ru = '????????????'; en = 'String'; pl = 'Wiersz';es_ES = 'L??nea';es_CO = 'L??nea';tr = 'Dize';it = 'Riga';de = 'Zeichenfolge'"));
	
	TypeString = TypePresentation;
	
EndProcedure

#EndRegion

