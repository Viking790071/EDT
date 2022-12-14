#Region Public

// Allows editing of locked form items linked to the specified attributes.
//
// Parameters:
//  Form - ClientApplicationForm - form, in which it is required to allow to edit form items of the specified 
//                 attributes.
//
//  FollowUpHandler - Undefined - no actions after the procedure execution.
//                       - NotifyDescription - notification that is called after the procedure execution.
//                         A Boolean parameter is passed to the notification handler:
//                           True - no references are found or the user decided to allow editing.
//                           False - no visible attributes are locked, or references are found and 
//                                    the user decided to cancel the operation.
//
Procedure AllowObjectAttributeEdit(Val Form, ContinuationHandler = Undefined) Export
	
	LockedAttributes = Attributes(Form, , False);
	
	If LockedAttributes.Count() = 0 Then
		ShowAllVisibleAttributesUnlockedWarning(
			New NotifyDescription("AllowObjectAttributeEditAfterWarning",
				ObjectAttributesLockInternalClient, ContinuationHandler));
		Return;
	EndIf;
	
	AttributeSynonyms = New Array;
	
	For Each AttributeDetails In Form.AttributeEditProhibitionParameters Do
		If LockedAttributes.Find(AttributeDetails.AttributeName) <> Undefined Then
			AttributeSynonyms.Add(AttributeDetails.Presentation);
		EndIf;
	EndDo;
	
	RefsArray = New Array;
	RefsArray.Add(Form.Object.Ref);
	
	Parameters = New Structure;
	Parameters.Insert("Form", Form);
	Parameters.Insert("LockedAttributes", LockedAttributes);
	Parameters.Insert("ContinuationHandler", ContinuationHandler);
	
	CheckObjectRefs(
		New NotifyDescription("AllowObjectAttributeEditAfterCheckRefs",
			ObjectAttributesLockInternalClient, Parameters),
		RefsArray,
		AttributeSynonyms);
	
EndProcedure

// Sets the availability of form items associated with the specified attributes whose editing is 
// allowed. Passing an attribute array to the procedure expands the set of attributes whose editing 
// is allowed.
//   If unlocking of form items linked to the specified attributes
// is released for all of the attributes, the button that allows editing becomes unavailable.
//
// Parameters:
//  Form - ClientApplicationForm - form, in which it is required to allow to edit form items of the specified 
//                 attributes.
//  
//  Attributes - Array - values:
//                  * String - names of attributes whose editing shall be allowed.
//                    It is used when the AllowObjectAttributeEdit function is not used.
//               - Undefined - the set of attributes available for editing is not changed. The form 
//                 items linked to the attributes whose editing is allowed, become available.
//                 
//
Procedure SetFormItemEnabled(Val Form, Val Attributes = Undefined) Export
	
	SetAttributeEditEnabling(Form, Attributes);
	
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		If DescriptionOfAttributeToLock.EditingAllowed Then
			For Each FormItemToLock In DescriptionOfAttributeToLock.ItemsToLock Do
				FormItem = Form.Items.Find(FormItemToLock.Value);
				If FormItem <> Undefined Then
					If TypeOf(FormItem) = Type("FormField")
					   AND FormItem.Type <> FormFieldType.LabelField
					 Or TypeOf(FormItem) = Type("FormTable") Then
						FormItem.ReadOnly = False;
					Else
						FormItem.Enabled = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Prompts a user to confirm that they want to allow attribute editing and checks if there are any 
// references to the object in the infobase.
//
// Parameters:
//  FollowUpHandler - NotifyDescription - notification called after the check.
//                         A Boolean parameter is passed to the notification handler:
//                           True - no references are found or the user decided to allow editing.
//                           False - no visible attributes are locked, or references are found and 
//                                    the user decided to cancel the operation.
//  RefArrray - Array - values:
//                           * Reference - searched references in various objects.
//  AttributeSynonyms - Array - values:
//                           * String - attribute synonyms displayed to a user.
//
Procedure CheckObjectRefs(Val ContinuationHandler, Val RefsArray, Val AttributeSynonyms) Export
	
	DialogTitle = NStr("ru = '???????????????????? ???????????????????????????? ????????????????????'; en = 'Allow editing attributes'; pl = 'Zezwalaj na edycj?? atrybut??w';es_ES = 'Permitir la edici??n de atributos';es_CO = 'Permitir la edici??n de atributos';tr = '??znitelikleri d??zenlemeye izin ver';it = 'Consentire la modifica degli attributi';de = 'Bearbeitung von Attributen zulassen'");
	
	AttributesPresentation = "";
	For Each AttributeSynonym In AttributeSynonyms Do
		AttributesPresentation = AttributesPresentation + AttributeSynonym + "," + Chars.LF;
	EndDo;
	AttributesPresentation = Left(AttributesPresentation, StrLen(AttributesPresentation) - 2);
	
	If AttributeSynonyms.Count() > 1 Then
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????????? ???? ?????????????????? ?????????????????????????????? ???????????? ?? ??????????????????,
			           |?????????????????? ?????????????????? ???? ???????????????? ?????? ????????????????????????????:
			           |%1.
			           |
			           |?????????? ??????, ?????? ?????????????????? ???? ????????????????????????????, ?????????????????????????? ?????????????? ??????????????????????,
			           |???????????????? ?????? ?????????? ?????????????????????????? ?????????? ???????????????? ?? ??????????????????.
			           |?????????? ???????? ?????????????????????????? ?????????? ???????????? ???????????????????? ??????????.'; 
			           |en = 'To prevent data inconsistency in the application,
			           |the following attributes cannot be edited:
			           |%1.
			           |
			           |It is recommended that you review the effects before allowing their editing
			           |by checking all usage locations of this item in the application.
			           |Usage location search may take a long time.'; 
			           |pl = 'W celu niedopuszczenia zak????ce?? danych w programie,
			           |nast??puj??ce atrybuty nie s?? dost??pne do edycji:
			           |%1.
			           |
			           |Przed pozwoleniem ich edycji zalecane jest oceni?? konsekwencje,
			           |sprawdzi?? wszystkie miejsca stosowania tego elementu w programie.
			           |Wyszukanie miejsc stosowania mo??e zaj???? du??o czasu.';
			           |es_ES = 'Para evitar el desajuste de datos en la aplicaci??n,
			           |los atributos no se editan de la siguiente manera: 
			           |%1.
			           |
			           |Antes de permitir su edici??n, se recomienda evaluar las consecuencias
			           |revisando todos las ubicaciones del uso de este art??culo en la aplicaci??n.
			           |B??squeda de ubicaciones de uso puede llevar mucho tiempo.';
			           |es_CO = 'Para evitar el desajuste de datos en la aplicaci??n,
			           |los atributos no se editan de la siguiente manera: 
			           |%1.
			           |
			           |Antes de permitir su edici??n, se recomienda evaluar las consecuencias
			           |revisando todos las ubicaciones del uso de este art??culo en la aplicaci??n.
			           |B??squeda de ubicaciones de uso puede llevar mucho tiempo.';
			           |tr = 'Uygulamada veri tutars??zl??????n??n ??nlenmesi i??in
			           |??u ??zellikler d??zenlenemez:
			           |%1.
			           |
			           |D??zenlemelerine izin vermeden ??nce, uygulamada bu ????enin t??m kullan??m yerlerini kontrol ederek
			           |sonu??lar?? de??erlendirmeniz ??nerilir.
			           |Kullan??m yerlerinin aranmas?? uzun zaman alabilir.';
			           |it = 'Al fine di preservare l''incosistenza dei dati nell''applicazione,
			           |i seguenti attributi non possono essere modificati:
			           |%1.
			           |
			           |E'' importante che verifichiate gli effetti prima di procedere con la modifica
			           |controllando tutti i luoghi dove questi elementi sono utilizzati nell''applicazione.
			           |La verifica dei luoghi di utilizzo potrebbe richiedere molto tempo.';
			           |de = 'Um Fehlausrichtungen von Daten in der Anwendung zu vermeiden,
			           |k??nnen die Attribute nicht wie folgt bearbeitet werden:
			           |%1.
			           |
			           |Vor dem Zulassen der Bearbeitung wird empfohlen, die Konsequenzen
			           |zu bewerten, indem Sie alle Stellen dieser Elementverwendung in der Anwendung ??berpr??fen.
			           |Das Suchen von Einsatzorten kann lange dauern.'"),
			AttributesPresentation);
	Else
		If RefsArray.Count() = 1 Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????? ???????? ?????????? ???? ?????????????????? ?????????????????????????????? ???????????? ?? ??????????????????,
				           |???????????????? %1 ???? ???????????????? ?????? ????????????????????????????.
				           |
				           |?????????? ??????, ?????? ?????????????????? ?????? ????????????????????????????, ?????????????????????????? ?????????????? ??????????????????????,
				           |???????????????? ?????? ?????????? ?????????????????????????? ""%2"" ?? ??????????????????.
				           |?????????? ???????? ?????????????????????????? ?????????? ???????????? ???????????????????? ??????????.'; 
				           |en = 'To prevent data inconsistency in the application,
				           |attribute %1 cannot be edited.
				           |
				           |It is recommended that you review the effects before allowing its editing
				           |by checking all usage locations ""%2"" in the application.
				           |Usage location search may take a long time.'; 
				           |pl = 'Aby unikn???? niedopasowania danych w aplikacji,
				           |atrybut %1 nie jest edytowalny.
				           |
				           |Przed zezwoleniem na jego edycj??, zaleca si?? oceni?? konsekwencje,
				           |sprawdzaj??c wszystkie miejsca u??ycia elementu ""%2"" w aplikacji.
				           |Wyszukiwanie miejsc u??ycia mo??e zaj???? du??o czasu.';
				           |es_ES = 'Para evitar el desajuste de datos en la aplicaci??n,
				           | el %1 atributo no es editable.
				           |
				           |Antes de permitir su edici??n, se recomienda evaluar las consecuencias
				           |revisando todas las ubicaciones del uso del art??culo ""%2"" en la aplicaci??n.
				           |B??squeda de ubicaciones de uso puede llevar mucho tiempo.';
				           |es_CO = 'Para evitar el desajuste de datos en la aplicaci??n,
				           | el %1 atributo no es editable.
				           |
				           |Antes de permitir su edici??n, se recomienda evaluar las consecuencias
				           |revisando todas las ubicaciones del uso del art??culo ""%2"" en la aplicaci??n.
				           |B??squeda de ubicaciones de uso puede llevar mucho tiempo.';
				           |tr = 'Uygulamadaki verilerin yanl???? hizalanmas??n?? ??nlemek i??in, 
				           |??zellik %1 d??zenlenemez. 
				           |
				           |D??zenlemesine izin vermeden ??nce, uygulamadaki "
" ????esinin t??m kullan??m yerlerini kontrol ederek sonu??lar??n 
				           |de??erlendirilmesi ??nerilir. %2Kullan??m yerlerinin aranmas?? uzun zaman alabilir.';
				           |it = 'Al fine di preservare l''incosistenza dei dati nell''applicazione,
				           |l''attributo %1 non pu?? essere modificato.
				           |
				           |E'' importante che verifichiate gli effetti prima di procedere con la modifica
				           |controllando tutti i luoghi di utilizzo ""%2"" nell''applicazione.
				           |La verifica dei luoghi di utilizzo potrebbe richiedere molto tempo.';
				           |de = 'Um Fehlausrichtung von Daten in der Anwendung zu vermeiden, kann
				           |das %1 Attribut nicht bearbeitet werden.
				           |
				           |Vor dem Zulassen seiner Bearbeitung wird empfohlen, die Konsequenzen zu bewerten,
				           |indem alle Stellen der ""%2"" Artikelverwendung in der Anwendung ??berpr??ft werden.
				           |Das Suchen von Einsatzorten kann lange dauern.'"),
				AttributesPresentation, RefsArray[0]);
		Else
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????? ???????? ?????????? ???? ?????????????????? ?????????????????????????????? ???????????? ?? ??????????????????,
				           |???????????????? %1 ???? ???????????????? ?????? ????????????????????????????.
				           |
				           |?????????? ??????, ?????? ?????????????????? ?????? ????????????????????????????, ?????????????????????????? ?????????????? ??????????????????????,
				           |???????????????? ?????? ?????????? ?????????????????????????? ?????????????????? ?????????????????? (%2) ?? ??????????????????.
				           |?????????? ???????? ?????????????????????????? ?????????? ???????????? ???????????????????? ??????????.'; 
				           |en = 'To prevent data inconsistency in the application,
				           |attribute %1 cannot be edited.
				           |
				           |It is recommended that you review the effects in the application before allowing its editing
				           |by checking all usage locations of the selected items (%2).
				           |Usage location search may take a long time.'; 
				           |pl = 'W celu niedopuszczenia zak????ce?? danych w programie,
				           |atrybut %1 nie jest dost??pny do edycji.
				           |
				           |Przed pozwoleniem jego edycji, zalecane jest oceni?? konsekwencje,
				           |sprawdzi?? wszystkie miejsca stosowania wybranych element??w (%2) w programie.
				           |Wyszukanie miejsc stosowania mo??e zaj???? du??o czasu.';
				           |es_ES = 'Para evitar el desajuste de datos en la aplicaci??n,
				           | el atributo %1 no es editable.
				           |
				           |Antes de permitir su edici??n, se recomienda evaluar las consecuencias
				           |revisando todas las ubicaciones del uso del art??culo (%2) en la aplicaci??n.
				           |B??squeda de ubicaciones de uso puede llevar mucho tiempo.';
				           |es_CO = 'Para evitar el desajuste de datos en la aplicaci??n,
				           | el atributo %1 no es editable.
				           |
				           |Antes de permitir su edici??n, se recomienda evaluar las consecuencias
				           |revisando todas las ubicaciones del uso del art??culo (%2) en la aplicaci??n.
				           |B??squeda de ubicaciones de uso puede llevar mucho tiempo.';
				           |tr = 'Uygulamadaki verilerin yanl???? hizalanmas??n?? ??nlemek i??in, 
				           |??zellik %1 d??zenlenemez. 
				           |
				           |D??zenlemesine izin vermeden ??nce, uygulamadaki "
" ????esinin t??m kullan??m yerlerini kontrol ederek sonu??lar??n 
				           |de??erlendirilmesi ??nerilir. %2Kullan??m yerlerinin aranmas?? uzun zaman alabilir.';
				           |it = 'Al fine di preservare l''incosistenza dei dati nell''applicazione,
				           |l''attributo %1 non pu?? essere modificato.
				           |
				           |E'' importante che verifichiate gli effetti prima di procedere con la modifica
				           |controllando tutti i luoghi di utilizzo degli elementi selezionati  (%2).
				           |La verifica dei luoghi di utilizzo potrebbe richiedere molto tempo.';
				           |de = 'Um Fehlausrichtung von Daten in der Anwendung zu vermeiden, kann
				           |das %1 Attribut nicht bearbeitet werden.
				           |
				           |Vor dem Zulassen seiner Bearbeitung wird empfohlen, die Konsequenzen zu bewerten,
				           |indem alle Stellen der ""%2"" Artikelverwendung in der Anwendung ??berpr??ft werden.
				           |Das Suchen von Einsatzorten kann lange dauern.'"),
				AttributesPresentation, RefsArray.Count());
		EndIf;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("RefsArray", RefsArray);
	Parameters.Insert("AttributeSynonyms", AttributeSynonyms);
	Parameters.Insert("DialogTitle", DialogTitle);
	Parameters.Insert("ContinuationHandler", ContinuationHandler);
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("ru = '?????????????????? ?? ??????????????????'; en = 'Check and allow'; pl = 'Sprawd?? i zezw??l';es_ES = 'Revisar y permitir';es_CO = 'Revisar y permitir';tr = 'Kontrol et ve izin ver';it = 'Controlla e consenti';de = '??berpr??fen und erlauben'"));
	Buttons.Add(DialogReturnCode.No, NStr("ru = '????????????'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = '??ptal et';it = 'Annulla';de = 'Abbrechen'"));
	
	ShowQueryBox(
		New NotifyDescription("CheckObjectReferenceAfterValidationConfirm",
			ObjectAttributesLockInternalClient, Parameters),
		QuestionText, Buttons, , DialogReturnCode.Yes, DialogTitle);
	
EndProcedure

// Allows editing the attributes whose descriptions are given in the form.
//  Used when form item availability??is changed explicitly
// without using the SetFormItemEnabled function.
//
// Parameters:
//  Form - Managed Form - form, in which you need to allow editing of object attributes.
//  
//  Attributes - Array - values.
//                  * String - attribute names. Editing of these attributes will be allowed.
//  
//  EditAllowed - Boolean - flag that shows whether you want to allow attribute editing.
//                            Can be set to True only if the edit right is granted.
//                          - Undefined - do not change the attribute editing status.
// 
//  RightToEdit - Boolean - flag used to override availability of unlocking attributes. It is 
//                        determined automatically using the AccessRight method.
//                      - Undefined - do not change the RightToEdit property.
// 
Procedure SetAttributeEditEnabling(Val Form, Val Attributes,
			Val EditingAllowed = True, Val RightToEdit = Undefined) Export
	
	If TypeOf(Attributes) = Type("Array") Then
		
		For Each Attribute In Attributes Do
			AttributeDetails = Form.AttributeEditProhibitionParameters.FindRows(New Structure("AttributeName", Attribute))[0];
			If TypeOf(RightToEdit) = Type("Boolean") Then
				AttributeDetails.EditRight = RightToEdit;
			EndIf;
			If TypeOf(EditingAllowed) = Type("Boolean") Then
				AttributeDetails.EditingAllowed = AttributeDetails.EditRight AND EditingAllowed;
			EndIf;
		EndDo;
	EndIf;
	
	// Updating the availability of AllowObjectAttributeEdit command.
	AllAttributesUnlocked = True;
	
	For each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		If DescriptionOfAttributeToLock.EditRight
		AND NOT DescriptionOfAttributeToLock.EditingAllowed Then
			AllAttributesUnlocked = False;
			Break;
		EndIf;
	EndDo;
	
	If AllAttributesUnlocked Then
		Form.Items.AllowObjectAttributeEdit.Enabled = False;
	EndIf;
	
EndProcedure

// Returns an array of attribute names??specified in the AttributeLockParameters form value based on 
// the attribute names specified in the object manager module excluding the attributes with 
// RightToEdit = False.
//
// Parameters:
//  Form - ClientApplicationForm - object form with a required standard Object attribute.
//  OnlyBlocked - Boolean - you can set this parameter to False for debug purposes, to get a list of 
//                  all visible attributes that can be unlocked.
//  OnlyVisible - Boolean - set this parameter to False to get and unlock all object attributes.
//
// Returns:
//  Array - values:
//   * String - attribute names.
//
Function Attributes(Val Form, Val OnlyBlocked = True, OnlyVisible = True) Export
	
	Attributes = New Array;
	
	For Each DescriptionOfAttributeToLock In Form.AttributeEditProhibitionParameters Do
		
		If DescriptionOfAttributeToLock.EditRight
		   AND (    DescriptionOfAttributeToLock.EditingAllowed = False
		      OR OnlyBlocked = False) Then
			
			AddAttribute = False;
			For Each FormItemToLock In DescriptionOfAttributeToLock.ItemsToLock Do
				FormItem = Form.Items.Find(FormItemToLock.Value);
				If FormItem <> Undefined AND (FormItem.Visible Or NOT OnlyVisible) Then
					AddAttribute = True;
					Break;
				EndIf;
			EndDo;
			If AddAttribute Then
				Attributes.Add(DescriptionOfAttributeToLock.AttributeName);
			EndIf;
		EndIf;
	EndDo;
	
	Return Attributes;
	
EndFunction

// Displays a warning that all visible attributes are unlocked.
// The warning is required when the unlock command remains enabled because of invisible locked 
// attributes.
//
// Parameters:
//  FollowUpHandler - Undefined - no actions after the procedure execution.
//                       - NotifyDescription - notification that is called after the procedure execution.
//
Procedure ShowAllVisibleAttributesUnlockedWarning(ContinuationHandler = Undefined) Export
	
	ShowMessageBox(ContinuationHandler,
		NStr("ru = '???????????????????????????? ???????? ?????????????? ???????????????????? ?????????????? ?????? ??????????????????.'; en = 'Editing all visible object attributes is already allowed.'; pl = 'Edytowanie wszystkich widocznych atrybut??w obiekt??w jest dozwolone.';es_ES = 'Edici??n de todos los atributos del objeto visibles permitida.';es_CO = 'Edici??n de todos los atributos del objeto visibles permitida.';tr = '??zin verilen t??m g??r??nen nesne niteliklerini d??zenleme.';it = 'La modifica di tutti gli attributi dell''oggetto ?? gi?? permessa.';de = 'Bearbeiten aller sichtbaren Objektattribute erlaubt.'"));
	
EndProcedure

#EndRegion
