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
			ShowMessageBox(, NStr("ru = 'Некорректное имя параметра. Параметр с таким именем уже был добавлен ранее.'; en = 'Placeholder name error. A placeholder with this name already exists.'; pl = 'Błąd nazwy symbolu zastępczego. Symbol zastępczy o tej nazwie już istnieje.';es_ES = 'Error en el nombre del marcador de posición. Ya existe un marcador de posición con este nombre.';es_CO = 'Error en el nombre del marcador de posición. Ya existe un marcador de posición con este nombre.';tr = 'Yer tutucu adı hatası. Bu ada sahip bir yer tutucu zaten var.';it = 'Errore nome segnaposto. Esiste già un segnaposto con questo nome.';de = 'Fehler des Platzhalternamens. Es existiert bereits ein Platzhalter mit diesem Namen.'"));
			Return;
		EndIf;
		If StrCompare(ParameterFromForm.Presentation, ParameterPresentation) = 0 Then
			ShowMessageBox(, NStr("ru = 'Некорректное представление параметра. Параметр с таким представлением уже был добавлен ранее.'; en = 'Placeholder presentation error. A placeholder with this presentation already exists.'; pl = 'Błąd prezentacji symbolu zastępczego. symbol zastępczy z tą prezentacją już istnieje.';es_ES = 'Error de presentación del marcador de posición. Ya existe un marcador de posición con esta presentación.';es_CO = 'Error de presentación del marcador de posición. Ya existe un marcador de posición con esta presentación.';tr = 'Yer tutucu sunum hatası. Bu sunuma sahip bir yer tutucu zaten mevcut.';it = 'Errore di presentazione del segnaposto. Esiste già un segnaposto con questa presentazione.';de = 'Fehler bei der Präsentation des Platzhalters. Es existiert bereits ein Platzhalter mit dieser Präsentation.'"));
			Return;
		EndIf;
	EndDo;
	
	If InvalidParameterName(ParameterName) OR IsBlankString(ParameterName) Then
		ShowMessageBox(, NStr("ru = 'Некорректное имя параметра. Нельзя использовать пробелы, знаки пунктуации и другие спец. символы.'; en = 'Invalid placeholder name. Special characters and whitespace are not allowed.'; pl = 'Nieprawidłowa nazwa symbolu zastępczego. Znaki specjalne i spacje nie są dozwolone.';es_ES = 'Nombre de marcador de posición inválido. No se permiten caracteres especiales ni espacios en blanco.';es_CO = 'Nombre de marcador de posición inválido. No se permiten caracteres especiales ni espacios en blanco.';tr = 'Geçersiz yer tutucu adı. Özel karakterler ve boşluk kullanılamaz.';it = 'Nome segnaposto non valido. Caratteri speciali e spazi non sono ammessi.';de = 'Ungültiger Platzhaltername. Sonderzeichen und Leerraum sind nicht erlaubt.'"));
		Return;
	EndIf;
	
	If IsBlankString(ParameterPresentation) Then
		ShowMessageBox(, NStr("ru = 'Некорректное представление параметра.'; en = 'Invalid placeholder presentation.'; pl = 'Nieprawidłowa prezentacja symbolu zastępczego.';es_ES = 'Presentación de marcador de posición no válida.';es_CO = 'Presentación de marcador de posición no válida.';tr = 'Geçersiz yer tutucu sunumu.';it = 'Presentazione segnaposto non valida.';de = 'Ungültige Platzhalterpräsentation.'"));
		Return;
	EndIf;
	
	If IsBlankString(TypeString) Then
		ShowMessageBox(, NStr("ru = 'Некорректный тип параметра.'; en = 'Invalid placeholder type.'; pl = 'Niepoprawny typ symbolu zastępczego.';es_ES = 'Tipo de marcador de posición no válido.';es_CO = 'Tipo de marcador de posición no válido.';tr = 'Geçersiz yer tutucu türü.';it = 'Tipo di segnaposto non valido.';de = 'Ungültiger Platzhalter-Typ.'"));
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
		TypePresentation = NStr("ru = 'Строка'; en = 'String'; pl = 'Wiersz';es_ES = 'Línea';es_CO = 'Línea';tr = 'Dize';it = 'Riga';de = 'Zeichenfolge'");
	ElsIf ParameterType = Type("Date") Then
		TypePresentation = NStr("ru = 'Дата'; en = 'Date'; pl = 'Data';es_ES = 'Fecha';es_CO = 'Fecha';tr = 'Tarih';it = 'Data';de = 'Datum'");
	EndIf;
	
	Items.TypeString.ChoiceList.Insert(0, "Date", NStr("ru = 'Дата'; en = 'Date'; pl = 'Data';es_ES = 'Fecha';es_CO = 'Fecha';tr = 'Tarih';it = 'Data';de = 'Datum'"));
	Items.TypeString.ChoiceList.Insert(0, "String", NStr("ru = 'Строка'; en = 'String'; pl = 'Wiersz';es_ES = 'Línea';es_CO = 'Línea';tr = 'Dize';it = 'Riga';de = 'Zeichenfolge'"));
	
	TypeString = TypePresentation;
	
EndProcedure

#EndRegion

