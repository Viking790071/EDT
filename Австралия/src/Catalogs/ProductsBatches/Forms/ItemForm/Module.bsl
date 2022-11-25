
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	If ValueIsFilled(Object.Owner)
		And Not Common.ObjectAttributeValue(Object.Owner, "UseBatches") Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cannot create a batch. Batch tracking is disabled for the product. To enable it, on the product card, open the Additional data tab and select the Batches checkbox.
			|If the checkbox is missing, on the General tab, do either of the following:
			|- Open the product category details and select the Batches checkbox.
			|- Select a product category with the Batches checkbox selected.
			|The Batches checkbox will appear on the Additional data tab. Select it. Then try again.'; 
			|ru = 'Не удается создать партию. Учет по партиям для номенклатуры отключен. Чтобы включить его, в карточке номенклатуры откройте вкладку ""Дополнительные данные"" и установите флажок ""Партии"".
			|Если флажок отсутствует, на вкладке ""Основные данные"" выполните одно из следующих действий:
			|- Откройте категорию номенклатуры и установите флажок ""Партии"".
			|- Выберите категорию номенклатуры с установленным флажком ""Партии"".
			|Флажок ""Партии"" появится на вкладке ""Дополнительные данные"". Выберите его. Затем попробуйте еще раз.';
			|pl = 'Nie można utworzyć partii. Śledzenie partii jest wyłączone dla produktu. Aby włączyć go na karcie produktu, otwórz wkładkę Informacje dodatkowe i zaznacz pole wyboru Partie.
			|Jeśli brakuje pole wyboru, na wkładce Informacje ogólne, wykonaj następujące czynności:
			|- Otwórz szczegóły kategorii produktu i zaznacz pole wyboru Partie.
			|- Wybierz kategorie produktów z zaznaczonym polem wyboru Partie.
			|Pole wyboru Partie pojawi się na wkładce Dane dodatkowe. Zaznacz go. Następnie spróbuj ponownie.';
			|es_ES = 'No se ha podido crear un lote. El rastreo del lote está desactivado para el producto. Para activarlo, en la tarjeta del producto, abra la pestaña Datos adicionales y seleccione la casilla de verificación Lotes.
			|Si la casilla no está activada, en la pestaña General, haga lo siguiente:
			|-Abra los detalles de la categoría del producto y seleccione la casilla de verificación Lotes.
			|-Seleccione una categoría de producto con la casilla de verificación Lotes seleccionada.
			|La casilla de verificación Lotes aparecerá en la pestaña Datos adicionales. Selecciónela. A continuación, inténtelo de nuevo.';
			|es_CO = 'No se ha podido crear un lote. El rastreo del lote está desactivado para el producto. Para activarlo, en la tarjeta del producto, abra la pestaña Datos adicionales y seleccione la casilla de verificación Lotes.
			|Si la casilla no está activada, en la pestaña General, haga lo siguiente:
			|-Abra los detalles de la categoría del producto y seleccione la casilla de verificación Lotes.
			|-Seleccione una categoría de producto con la casilla de verificación Lotes seleccionada.
			|La casilla de verificación Lotes aparecerá en la pestaña Datos adicionales. Selecciónela. A continuación, inténtelo de nuevo.';
			|tr = 'Parti oluşturulamıyor. Ürün için parti takibi kapalı. Etkinleştirmek için ürün kartında Ek veriler sekmesini açıp Partiler onay kutusunu işaretleyin.
			|Onay kutusu yoksa Genel sekmesinde şu işlemlerden birini yapın:
			|- Ürün kategorisi bilgilerini açıp Partiler onay kutusunu işaretleyin.
			|- Partiler onay kutusu işaretlenmiş bir ürün kategorisi seçin.
			|Partiler onay kutusu Ek veriler sekmesinde görünür. Onay kutusunu işaretleyip tekrar deneyin.';
			|it = 'Impossibile creare un lotto. Il tracciamento lotti è disattivato per l''articolo. Per attivarlo, aprire nella scheda articolo la scheda Dati aggiuntivi e selezionare la casella di controllo Lotti.
			|Se la casella di controllo è mancante, nella scheda Generale scegliere una delle seguenti azioni:
			|- Aprire i dettagli della categoria articolo e selezionare la casella di controllo Lotti.
			|- Selezionare una categoria di articolo con la casella di controllo Lotti selezionata.
			|La casella di controllo Lotti apparirà sulla scheda Dati aggiuntivi. Selezionarla e riprovare.';
			|de = 'Fehler beim Erstellen einer Charge. Chargenverfolgung ist für das Produkt deaktiviert. Um sie zu aktivieren, öffnen Sie in der Produktkarte die Registerkarte Weitere Angaben und aktivieren Sie das Kontrollkästchen Chargen.
			|Sollte es kein Kontrollkästchen sein, führen Sie einen der folgenden Schritten aus:
			|- Öffnen Sie die Details der Produktkategorie und aktivieren Sie das Kontrollkästchen Chargen.
			|- Wählen Sie eine Produktkategorie mit dem aktivierten Kontrollkästchen Chargen.
			|Das Kontrollkästchen Chargen erscheint auf der Registerkarte Weitere Angaben. Aktivieren Sie es. Dann versuchen Sie erneut.'");
		Message.Message();
		Cancel = True;
		Return;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
	If Parameters.Key.IsEmpty() Then
		
		GetApplyBatchSettings();
		
		NumberPartsTable = CurrentMaxBatchNumbers(Object.Owner);
		For Each NumberPartsRow In NumberPartsTable Do
			NextBatchNumber = NextBatchNumber(NumberPartsRow);
			If Not IsBlankString(NextBatchNumber) Then
				Items.BatchNumber.ChoiceList.Add(NextBatchNumber);
			EndIf;
		EndDo;
		If Items.BatchNumber.ChoiceList.Count() > 0 Then
			Items.BatchNumber.DropListButton = True;
		EndIf;
		
		If ValueIsFilled(Parameters.CopyingValue)
			And Not IsBlankString(Object.BatchNumber) Then
			NumberParts = SplitBatchNumber(Object.BatchNumber);
			Object.BatchNumber = "";
			If NumberParts.NumberLength > 0 Then
				SearchFilter = New Structure("Prefix, NumberLength");
				FillPropertyValues(SearchFilter, NumberParts);
				NumberPartsRows = NumberPartsTable.FindRows(SearchFilter);
				If NumberPartsRows.Count() > 0 Then
					Object.BatchNumber = NextBatchNumber(NumberPartsRows[0]);
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
	GetApplyBatchSettings();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	GenerateAutoDescription(Parameters.Key.IsEmpty());
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OwnerOnChange(Item)
	
	GetApplyBatchSettings();
	GenerateAutoDescription();
	
EndProcedure

&AtClient
Procedure BatchNumberOnChange(Item)
	
	Object.BatchNumber = TrimAll(Object.BatchNumber);
	
	GenerateAutoDescription();
	
EndProcedure

&AtClient
Procedure ExpirationDateOnChange(Item)
	
	Object.ExpirationDate = DriveClientServer.AdjustDateByPrecision(Object.ExpirationDate,
		BatchSettings.ExpirationDatePrecision);
	
	GenerateAutoDescription();
	
EndProcedure

&AtClient
Procedure ProductionDateOnChange(Item)
	
	Object.ProductionDate = DriveClientServer.AdjustDateByPrecision(Object.ProductionDate,
		BatchSettings.ProductionDatePrecision);
	
	GenerateAutoDescription();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function NextBatchNumber(NumberParts)
	
	NextNumber = NumberParts.Number + 1;
	
	If StrLen(Format(NextNumber, "NG=0")) > NumberParts.NumberLength Then
		
		Return "";
		
	Else
		
		FormatString = StringFunctionsClientServer.SubstituteParametersToString(
			"ND=%1; NLZ=; NG=0",
			NumberParts.NumberLength);
		
		Return NumberParts.Prefix + Format(NextNumber, FormatString);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function SplitBatchNumber(BatchNumber)
	
	Digits = "0123456789";
	
	TrimmedBatchNumber = TrimAll(BatchNumber);
	
	Length = StrLen(TrimmedBatchNumber);
	LastNondigit = 0;
	
	For Counter = 1 To Length Do
		If StrFind(Digits, Mid(TrimmedBatchNumber, Counter, 1)) = 0 Then
			LastNondigit = Counter;
		EndIf;
	EndDo;
	
	Result = New Structure;
	
	If LastNondigit < Length Then 
		Number = Number(Mid(TrimmedBatchNumber, LastNondigit + 1));
	Else
		Number = 0;
	EndIf;
	
	Result.Insert("Prefix", Left(TrimmedBatchNumber, LastNondigit));
	Result.Insert("NumberLength", Length - LastNondigit);
	Result.Insert("Number", Number);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function CurrentMaxBatchNumbers(Product)
	
	NumberPartsTable = New ValueTable;
	NumberPartsTable.Columns.Add("Prefix", Common.StringTypeDetails(30));
	NumberPartsTable.Columns.Add("NumberLength", Common.TypeDescriptionNumber(2));
	NumberPartsTable.Columns.Add("Number", Common.TypeDescriptionNumber(30));
	
	If Not ValueIsFilled(Product) Then
		Return NumberPartsTable;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Owner", Product);
	Query.Text =
	"SELECT
	|	ProductsBatches.BatchNumber AS BatchNumber
	|FROM
	|	Catalog.ProductsBatches AS ProductsBatches
	|WHERE
	|	ProductsBatches.Owner = &Owner
	|	AND ProductsBatches.BatchNumber <> """"";
	
	Sel = Query.Execute().Select();
	While Sel.Next() Do
		
		NumberParts = SplitBatchNumber(Sel.BatchNumber);
		
		If NumberParts.NumberLength > 0 Then
			
			SearchFilter = New Structure("Prefix, NumberLength");
			FillPropertyValues(SearchFilter, NumberParts);
			NumberPartsRows = NumberPartsTable.FindRows(SearchFilter);
			If NumberPartsRows.Count() > 0 Then
				NumberPartsRow = NumberPartsRows[0];
			Else
				NumberPartsRow = NumberPartsTable.Add();
			EndIf;
			If NumberParts.Number > NumberPartsRow.Number Then
				FillPropertyValues(NumberPartsRow, NumberParts);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return NumberPartsTable;
	
EndFunction

&AtClient
Procedure GenerateAutoDescription(Set = True)
	
	If Not IsBlankString(BatchSettings.DescriptionTemplate) Then
		
		AutoDescription = StringFunctionsClientServer.SubstituteParametersToString(BatchSettings.DescriptionTemplate,
			Object.BatchNumber,
			DriveClient.FormatDateByPrecision(Object.ExpirationDate, BatchSettings.ExpirationDatePrecision),
			DriveClient.FormatDateByPrecision(Object.ProductionDate, BatchSettings.ProductionDatePrecision));
			
		Items.Description.ChoiceList.Clear();
		Items.Description.ChoiceList.Add(AutoDescription);
		
		If Set Then
			Object.Description = AutoDescription;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GetApplyBatchSettings()
	
	BatchSettings = Catalogs.BatchSettings.ProductBatchSettings(Object.Owner);
	
	Items.BatchNumber.Visible = BatchSettings.UseBatchNumber;
	
	Items.ExpirationDate.Visible = BatchSettings.UseExpirationDate;
	If BatchSettings.UseExpirationDate Then
		Items.ExpirationDate.EditFormat = DriveClientServer.DatePrecisionFormatString(BatchSettings.ExpirationDatePrecision);
	EndIf;
	
	Items.ProductionDate.Visible = BatchSettings.UseProductionDate;
	If BatchSettings.UseProductionDate Then
		Items.ProductionDate.EditFormat = DriveClientServer.DatePrecisionFormatString(BatchSettings.ProductionDatePrecision);
	EndIf;
	
	If IsBlankString(BatchSettings.DescriptionTemplate) Then
		Items.Description.DropListButton = False;
		Items.Description.ChoiceList.Clear();
	Else
		Items.Description.DropListButton = True;
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#EndRegion

