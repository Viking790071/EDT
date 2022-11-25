
#Region FormEventHandlers

&AtClient
Var ResponseBeforeWrite;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then     
		Return;
	EndIf;

	CurrentUser = InfobaseUsers.CurrentUser();

	#If Not WebClient Then
	Object.ComputerName = ComputerName();
	#EndIf
	
	Items.Equipment.Enabled = ValueIsFilled(Object.Ref); 
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If IsBlankString(Object.Code) Then
		SystemInfo = New SystemInfo();
		Object.Code = Upper(SystemInfo.ClientID);
	EndIf;
	
	EquipmentManagerClientServer.FillWorkplaceDescription(Object, CurrentUser);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	place = CurrentObject.Ref;
	
	DeviceList = EquipmentManagerServerCall.GetEquipmentList( , , place);
	For Each Item In DeviceList Do
		If Item.Workplace = place Then
			LocalEquipment.Add(Item.Ref,Item.Description, False, GetPicture(Item.EquipmentType, 16));
		EndIf;
	EndDo;

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not UniquenessCheckByIDClient()Then
		Cancel = True;
		Text = NStr("en = 'Error workplace saving.
		            |Workplace with such client ID already exists.'; 
		            |ru = 'Ошибка сохранение рабочего места.
		            |Рабочее место с таким идентификатором клиента уже существует.';
		            |pl = 'Błąd zapisu miejsca pracy.
		            |Miejsce pracy z takim identyfikatorem klienta już istnieje.';
		            |es_ES = 'Error al guardar el lugar de trabajo.
		            |El lugar de trabajo con este identificador del cliente ya existe.';
		            |es_CO = 'Error al guardar el lugar de trabajo.
		            |El lugar de trabajo con este identificador del cliente ya existe.';
		            |tr = 'Çalışma alanı kaydedilemedi.
		            |Bu müşteri kimliğine sahip çalışma alanı zaten var.';
		            |it = 'Errore di salvataggio della postazione di lavoro.
		            |Una postazione di lavoro con questo client ID già esiste.';
		            |de = 'Fehler Arbeitsplatzsicherung.
		            |Ein Arbeitsplatz mit einer solchen Kunden-ID ist bereits vorhanden.'");
		CommonClientServer.MessageToUser(Text);
		Return;
	EndIf;
	
	If Not UniquenessCheckByDescription()Then
		If ResponseBeforeWrite <> True Then
			Cancel = True;
			Text = NStr("en = 'Nonunique workplace description is specified.
			            |It may probably complicate the identification and selection of a workplace in future.
			            |It is recommended to specify a unique workplace description.
			            |Continue saving with specified description?'; 
			            |ru = 'Указано неуникальное наименование рабочего места.
			            |Возможно в дальнейшем это затруднит идентификацию и выбор рабочего места.
			            |Рекомендуется указывать уникальное наименование рабочих мест.
			            |Продолжить сохранение с указанным наименованием?';
			            |pl = 'Wykryto nietypowy opis miejsca pracy.
			            |Prawdopodobnie może to utrudnić identyfikację i wybór miejsca pracy w przyszłości.
			            |Zaleca się podanie unikalnego opisu miejsca pracy.
			            |Kontynuować zapisywanie z określonym opisem?';
			            |es_ES = 'Descripción del lugar de trabajo no único especificado.
			            |Puede que se complique la identificación y la selección de un lugar de trabajo en el futuro.
			            |Se recomienda especificar una única descripción del lugar de trabajo.
			            |¿Continuar guardando con la descripción especificada?';
			            |es_CO = 'Descripción del lugar de trabajo no único especificado.
			            |Puede que se complique la identificación y la selección de un lugar de trabajo en el futuro.
			            |Se recomienda especificar una única descripción del lugar de trabajo.
			            |¿Continuar guardando con la descripción especificada?';
			            |tr = 'Benzersiz olmayan çalışma alanı tanımı belirtildi.
			            |Bu durum, daha sonra bir çalışma alanı tanımlamayı ve seçmeyi zorlaştırır.
			            |Benzersiz bir çalışma alanı tanımı belirtmeniz önerilir.
			            |Belirtilen tanımla kaydetmeye devam etmek istiyor musunuz?';
			            |it = 'Una descrizione della postazione di lavoro non univoca è stata specificata.
			            |Potrebbe in futuro complicare l''identificazione e selezione di una postazione di lavoro.
			            |Si consiglia di specificare una descrizione univoca della postazione di lavoro.
			            |Continuare e salvare con la descrizione specificata?';
			            |de = 'Es wird eine nicht eindeutige Arbeitsplatzbeschreibung angegeben.
			            |Es kann die Identifizierung und Auswahl eines Arbeitsplatzes in Zukunft möglicherweise erschweren.
			            |Es wird empfohlen, eine eindeutige Arbeitsplatzbeschreibung anzugeben.
			            |Mit der angegebenen Beschreibung weiter speichern?'");
			Notification = New NotifyDescription("BeforeWriteEnd", ThisObject);
			ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure BeforeWriteEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ResponseBeforeWrite = True;
		Write();
	EndIf;  
	
EndProcedure
   
&AtClient
Procedure AfterWrite(WriteParameters)
	
	SystemInfo = New SystemInfo();
	
	If Object.Code = Upper(SystemInfo.ClientID) Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	EquipmentManagerClientServer.FillWorkplaceDescription(Object, CurrentUser);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function UniquenessCheckByDescription()
	
	Result = True;
	
	If Not IsBlankString(Object.Description) Then
		Query = New Query("
		|SELECT
		|    1
		|FROM
		|    Catalog.Workplaces AS Workplaces
		|WHERE
		|    Workplaces.Description = &Description
		|    AND Workplaces.Ref <> &Ref
		|");
		Query.SetParameter("Description", Object.Description);
		Query.SetParameter("Ref"      , Object.Ref);
		Result = Query.Execute().IsEmpty();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function UniquenessCheckByIDClient()
	
	Result = True;
	
	SystemInfo = New SystemInfo();
	ClientID = Upper(SystemInfo.ClientID);
	
	If Not IsBlankString(Object.Code) Then
		Query = New Query("
		|SELECT
		|    1
		|FROM
		|    Catalog.Workplaces AS Workplaces
		|WHERE
		|    Workplaces.Code = &Code
		|    AND Workplaces.Ref <> &Ref
		|");
		Query.SetParameter("Code"    , ClientID);
		Query.SetParameter("Ref" , Object.Ref);
		Result = Query.Execute().IsEmpty();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function GetPicture(EquipmentType, Size)
	
	Try // Empty reference or undefined can come, there may be no image.
		MetaObject  = EquipmentType.Metadata();
		IndexOf      = Enums.PeripheralTypes.IndexOf(EquipmentType);
		IconName = MetaObject.EnumValues[IndexOf].Name;
		IconName = "Peripherals" + IconName + Size;
		Picture = PictureLib[IconName]
	Except
		Picture = Undefined;
	EndTry;
	
	Return Picture;
	
EndFunction

#EndRegion