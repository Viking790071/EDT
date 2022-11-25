#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetVisibleAndEnabled();
	ReadTrackingPolicy();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		SetVisibleAndEnabled();
	EndIf;
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteTrackingPolicy(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AddDefaultTemplateToChoiceList(GetDefaultDescriptionTemplate());
	GenerateDescriptionExample();
	SetTrackingPolicyChoiceParameters();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	CheckedAttributes.Add("TrackingPolicy");
	
	MessageTemplate = NStr("en = 'In the tracking policies list, in line %2 , the ""%1"" field is required.'; ru = 'Не заполнено поле ""%1"" в строке %2 списка политик отслеживания.';pl = 'Na liście polityk śledzenia, w wierszu %2 , pole ""%1"" jest wymagane.';es_ES = 'En la lista de políticas de rastreo, en la línea %2 , el campo ""%1es obligatorio.';es_CO = 'En la lista de políticas de rastreo, en la línea %2 , el campo ""%1"" es obligatorio.';tr = 'Takip politikalarının %2 satırında ""%1"" alanı gerekli.';it = 'Nell''elenco delle policy di tracciamento, nella riga %2, è richiesto il campo ""%1"".';de = 'In der Liste der Tracking-Richtlinien ist in Zeile %2 das Feld ""%1“ erforderlich.'");
	
	For Each TrackingPolicyRecord In TrackingPolicy Do
		
		LineNumber = TrackingPolicy.IndexOf(TrackingPolicyRecord) + 1;
		
		If Not ValueIsFilled(TrackingPolicyRecord.StructuralUnit) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				NStr("en = 'Business unit'; ru = 'Подразделение';pl = 'Jednostka biznesowa';es_ES = 'Unidad empresarial';es_CO = 'Unidad de negocio';tr = 'Departman';it = 'Business unit';de = 'Abteilung'"),
				LineNumber);
			CommonClientServer.MessageToUser(MessageText, ,
				CommonClientServer.PathToTabularSection("TrackingPolicy", LineNumber, "StructuralUnit"),
				,
				Cancel);
		EndIf;
		
		If Not ValueIsFilled(TrackingPolicyRecord.Policy) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				NStr("en = 'Policy'; ru = 'Политика';pl = 'Polityka';es_ES = 'Política';es_CO = 'Política';tr = 'Politika';it = 'Politica';de = 'Richtlinie'"),
				LineNumber);
			CommonClientServer.MessageToUser(MessageText, ,
				CommonClientServer.PathToTabularSection("TrackingPolicy", LineNumber, "Policy"),
				,
				Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseBatchNumberOnChange(Item)
	
	SetDefaultDescriptionTemplate();
	GenerateDescriptionExample();
	
EndProcedure

&AtClient
Procedure UseExpirationDateOnChange(Item)
	
	Items.ExpirationDatePrecision.Visible = Object.UseExpirationDate;
	
	SetDefaultDescriptionTemplate();
	GenerateDescriptionExample();
	
	Object.DefaultTrackingPolicy = "";
	SetTrackingPolicyChoiceParameters();
	
EndProcedure

&AtClient
Procedure ExpirationDatePrecisionOnChange(Item)
	
	GenerateDescriptionExample();
	
EndProcedure

&AtClient
Procedure UseProductionDateOnChange(Item)
	
	Items.ProductionDatePrecision.Visible = Object.UseProductionDate;
	SetDefaultDescriptionTemplate();
	GenerateDescriptionExample();
	
EndProcedure

&AtClient
Procedure ProductionDatePrecisionOnChange(Item)
	
	GenerateDescriptionExample();
	
EndProcedure

&AtClient
Procedure DescriptionTemplateOnChange(Item)
	
	GenerateDescriptionExample();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	
EndProcedure

#EndRegion

#Region TrackingPolicyFormTableItemsEventHandlers

&AtClient
Procedure TrackingPolicyOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		CurRowData = Item.CurrentData;
		If Not ValueIsFilled(CurRowData.Policy) Then
			CurRowData.Policy = Object.DefaultTrackingPolicy;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ReadTrackingPolicy()
	
	RecordSet = FormAttributeToValue("TrackingPolicy");
	RecordSet.Filter.BatchSettings.Set(Object.Ref);
	RecordSet.Read();
	ValueToFormAttribute(RecordSet, "TrackingPolicy");
	
EndProcedure

&AtServer
Procedure WriteTrackingPolicy(CurrentObject)
	
	RecordSet = FormAttributeToValue("TrackingPolicy");
	RecordSet.Filter.BatchSettings.Set(CurrentObject.Ref);
	For Each Record In RecordSet Do
		Record.BatchSettings = CurrentObject.Ref;
	EndDo;
	RecordSet.Write();
	
EndProcedure

&AtClient
Procedure SetTrackingPolicyChoiceParameters()
	
	If Object.UseExpirationDate Then
		
		Items.DefaultTrackingPolicy.ChoiceParameters = New FixedArray(New Array);
		Items.TrackingPolicyPolicy.ChoiceParameters = New FixedArray(New Array);
		
	Else
		
		MethodsArray = New Array;
		MethodsArray.Add(PredefinedValue("Enum.BatchTrackingMethods.Manual"));
		MethodsArray.Add(PredefinedValue("Enum.BatchTrackingMethods.Referential"));
		ChoiceParameter = New ChoiceParameter("Filter.TrackingMethod", New FixedArray(MethodsArray));
		ChoiceParametersArray = New Array;
		ChoiceParametersArray.Add(ChoiceParameter);
		Items.DefaultTrackingPolicy.ChoiceParameters = New FixedArray(ChoiceParametersArray);
		Items.TrackingPolicyPolicy.ChoiceParameters = New FixedArray(ChoiceParametersArray);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabled()
	
	Items.ExpirationDatePrecision.Visible = Object.UseExpirationDate;
	Items.ProductionDatePrecision.Visible = Object.UseProductionDate;
	
EndProcedure

&AtClient
Procedure SetDefaultDescriptionTemplate()
	
	Object.DescriptionTemplate = GetDefaultDescriptionTemplate();
	AddDefaultTemplateToChoiceList(Object.DescriptionTemplate);
	
EndProcedure

&AtClient
Procedure AddDefaultTemplateToChoiceList(DefaultDescriptionTemplate)
	
	DT_ChoiceList = Items.DescriptionTemplate.ChoiceList;
	DT_ChoiceList.Clear();
	If Not IsBlankString(DefaultDescriptionTemplate) Then
		DT_ChoiceList.Add(DefaultDescriptionTemplate);
	EndIf;
	Items.DescriptionTemplate.DropListButton = (DT_ChoiceList.Count() > 0);
	
EndProcedure

&AtClient
Function GetDefaultDescriptionTemplate()
	
	TemplateElements = New Array;
	
	If Object.UseBatchNumber Then
		TemplateElements.Add(NStr("en = 'Batch No: %1'; ru = '№ партии: %1';pl = 'Nr partii: %1';es_ES = 'Lote No.:%1';es_CO = 'Lote No.:%1';tr = 'Parti No: %1';it = 'Lotto N.: %1';de = 'Charge Nr.: %1'"));
	EndIf;
	
	If Object.UseExpirationDate Then
		TemplateElements.Add(NStr("en = 'Exp. date: %2'; ru = 'Срок годности: %2';pl = 'Data ważności: %2';es_ES = 'Fecha de exp.:%2';es_CO = 'Fecha de exp.:%2';tr = 'Sona erme t.: %2';it = 'Data di scadenza: %2';de = 'Ablaufdatum: %2'"));
	EndIf;
	
	If Object.UseProductionDate Then
		TemplateElements.Add(NStr("en = 'Mfg. date: %3'; ru = 'Изготовлен: %3';pl = 'Data produkcji: %3';es_ES = 'Fecha de fab.: %3';es_CO = 'Fecha de fab.:%3';tr = 'Üretim t.: %3';it = 'Data di produzione: %3';de = 'Herstellungsdatum: %3'"));
	EndIf;
	
	Return StringFunctionsClientServer.StringFromSubstringArray(TemplateElements, "; ");
	
EndFunction

&AtClient
Procedure GenerateDescriptionExample()
	
	If IsBlankString(Object.DescriptionTemplate) Then
		DescriptionExample = "";
		Return;
	EndIf;
	
	If Object.UseBatchNumber Then
		BatchNumber = "1005002319";
	Else
		BatchNumber = "";
	EndIf;
	
	If Object.UseExpirationDate Then
		ExpirationDate = DriveClient.FormatDateByPrecision(EndOfYear(CurrentDate()), Object.ExpirationDatePrecision, True);
	Else
		ExpirationDate = "";
	EndIf;
	
	If Object.UseProductionDate Then
		ProductionDate = DriveClient.FormatDateByPrecision(CurrentDate(), Object.ProductionDatePrecision, True);
	Else
		ProductionDate = "";
	EndIf;
	
	Try
		DescriptionExample = StringFunctionsClientServer.SubstituteParametersToString(Object.DescriptionTemplate,
			BatchNumber, ExpirationDate, ProductionDate);
	Except
		DescriptionExample = NStr("en = 'The description template is invalid.
			|To reset the template, select the required batch details.'; 
			|ru = 'Недопустимый шаблон наименования.
			|Чтобы сбросить шаблон, выберите необходимое описание партии.';
			|pl = 'Szablon opisu jest nieprawidłowy.
			|Aby zresetować szablon, wybierz wymagane szczegóły partii.';
			|es_ES = 'La plantilla de descripción no es válida.
			|Para restablecer la plantilla, seleccione los detalles del lote requeridos.';
			|es_CO = 'La plantilla de descripción no es válida.
			|Para restablecer la plantilla, seleccione los detalles del lote requeridos.';
			|tr = 'Açıklama şablonu geçersiz.
			|Şablonu sıfırlamak için, gerekli parti bilgilerini seçin.';
			|it = 'Il modello di descrizione non è valido. 
			|Per reimpostare il modello, selezionare i dettagli di lotto richiesti.';
			|de = 'Die Beschreibungsvorlage ist ungültig.
			|Um die Vorlage zurückzusetzen, wählen Sie die erforderlichen Chargen-Details aus.'");
	EndTry;
	
EndProcedure

#Region LibrariesHandlers

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
	
EndProcedure

#EndRegion

#EndRegion