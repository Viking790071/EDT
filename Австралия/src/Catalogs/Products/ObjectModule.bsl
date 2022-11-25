#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		
		Return;
		
	EndIf;
	
	If ProductsType = Enums.ProductsTypes.InventoryItem Then
		
		CheckedAttributes.Add("BusinessLine");
		
	ElsIf ProductsType = Enums.ProductsTypes.Service Then
		
		CheckedAttributes.Add("BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ReplenishmentMethod");
		
	ElsIf ProductsType = Enums.ProductsTypes.Work Then
		
		CheckedAttributes.Add("BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ReplenishmentMethod");
		
	EndIf;
	
	If ValueIsFilled(ProductsCategory) And Not IsNew() Then
		
		OldData = Common.ObjectAttributesValues(Ref,
			"UseBatches, UseCharacteristics, UseSerialNumbers, ProductsCategory");
		
		If (UseBatches <> OldData.UseBatches)
			Or (UseCharacteristics <> OldData.UseCharacteristics)
			Or (UseSerialNumbers <> OldData.UseSerialNumbers)
			Or (ProductsCategory <> OldData.ProductsCategory) Then
			
			ProductCategoryData = Common.ObjectAttributesValues(ProductsCategory,
				"UseBatches, UseCharacteristics, UseSerialNumbers");
			
			If GetFunctionalOption("UseBatches")
				And UseBatches
				And Not ProductCategoryData.UseBatches Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot enable batch tracking for the product. Do one of the following:
						|• Enable batch tracking for the selected product category.
						|• Select a product category with batch tracking enabled.
						|• To disable batch tracking, clear the Batches check box.'; 
						|ru = 'Не удается включить учет по партиям для номенклатуры. Выполните одно из следующих действий:
						|• Включите учет по партиям для выбранной номенклатурной группы.
						|• Выберите номенклатурную группу с включенным учетом по партиям.
						|• Чтобы отключить учет по партиям, снимите флажок Партии.';
						|pl = 'Nie można włączyć śledzenia partii dla produktu. Wykonaj jedną z następujących czynności:
						|• Włącz śledzenie partii dla wybranej kategorii produktów.
						|• Wybierz kategorię produktów z włączonym śledzeniem partii.
						|• Aby wyłączyć śledzenie partii, wyczyść pole wyboru Partie.';
						|es_ES = 'No se puede habilitar el rastreo del lote del producto. Realice una de las siguientes acciones:
						|• Active el rastreo del lote para la categoría del producto seleccionada.
						|• Seleccione una categoría de productos con el rastreo del lote activado.
						|• Para desactivar el rastreo del lote, desmarque la casilla de verificación Lotes.';
						|es_CO = 'No se puede habilitar el rastreo del lote del producto. Realice una de las siguientes acciones:
						|• Active el rastreo del lote para la categoría del producto seleccionada.
						|• Seleccione una categoría de productos con el rastreo del lote activado.
						|• Para desactivar el rastreo del lote, desmarque la casilla de verificación Lotes.';
						|tr = 'Ürün için parti takibi etkinleştirilemiyor. Şunlardan birini deneyin:
						|• Seçili ürün kategorisi için parti takibini etkinleştirin.
						|• Parti takibi etkinleştirilmiş bir ürün kategorisi seçin.
						|• Parti takibini devre dışı bırakmak için Partiler onay kutusunu temizleyin.';
						|it = 'Impossibile attivare il tracciamento lotto per l''articolo. Provare una delle seguenti operazioni:
						|• Attivare il tracciamento lotto per la categoria di articolo selezionata.
						|• Selezionare una categoria di articolo con il tracciamento lotto attivo.
						|• Per disattivare il tracciamento lotto, deselezionare la casella di controllo Lotti.';
						|de = 'Die Chargenverfolgung für das Produkt kann nicht aktiviert werden.
						| Aktivieren Sie die Chargenverfolgung für die ausgewählte Produktkategorie.
						|Wählen Sie eine Produktkategorie mit der aktivierten Chargen-Verfolgung aus.
						|Um die Chargenverfolgung zu deaktivieren, deaktivieren Sie das Kontrollkästchen Chargen.'"),
					ThisObject, "UseBatches", , Cancel);
				
			EndIf;
			
			If GetFunctionalOption("UseCharacteristics")
				And UseCharacteristics
				And Not ProductCategoryData.UseCharacteristics Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot enable accounting by variants for the product. Do one of the following:
						|• Enable accounting by variants for the selected product category.
						|• Select a product category with accounting by variants enabled.
						|• To disable accounting by variants, clear the Variants check box.'; 
						|ru = 'Не удается включить учет по вариантам для номенклатуры. Выполните следующие действия:
						|• Включить учет по вариантам для выбранной номенклатурной группы.
						|• Выберите номенклатурную группу с включенным учетом по вариантам.
						|• Чтобы отключить учет по вариантам, снимите флажок Варианты.';
						|pl = 'Nie można włączyć ewidencjonowania według wariantów dla produktu. Wykonaj jedną z następujących czynności:
						|• Włącz ewidencjonowanie według wariantów dla wybranej kategorii produktów.
						|• Wybierz kategorie produktów z ewidencjonowaniem według wariantów.
						|• Aby wyłączyć ewidencjonowanie według wariantów, wyczyść pole wyboru Warianty.';
						|es_ES = 'No se puede activar la contabilidad por por variantes para el producto. Realice una de las siguientes acciones:
						|• Active la contabilidad por por variantes para la categoría de productos seleccionada.
						|• Seleccione una categoría de productos con la contabilidad por variantes activada.
						|• Para desactivar la contabilidad por variantes, desmarque la casilla de verificación por Variantes.';
						|es_CO = 'No se puede activar la contabilidad por por variantes para el producto. Realice una de las siguientes acciones:
						|• Active la contabilidad por por variantes para la categoría de productos seleccionada.
						|• Seleccione una categoría de productos con la contabilidad por variantes activada.
						|• Para desactivar la contabilidad por variantes, desmarque la casilla de verificación por Variantes.';
						|tr = 'Ürün için varyantlara göre muhasebe etkinleştirilemiyor. Şunlardan birini deneyin:
						|• Seçili ürün kategorisi için varyantlara göre muhasebeyi etkinleştirin.
						|• Varyantlara göre muhasebenin etkinleştirildiği bir ürün kategorisi seçin.
						|• Varyantlara göre muhasebeyi devre dışı bırakmak için Varyantlar onay kutusunu temizleyin.';
						|it = 'Impossibile attivare la contabilità per varianti per l''articolo. Provare una delle seguenti operazioni:
						|• Attivare contabilità per varianti per la categoria di articolo selezionata.:
						|• Selezionare una categoria di articolo con contabilità per varianti attivata.:
						|• Per disattivare la contabilità per varianti, deselezionare la casella di controllo Varianti.';
						|de = 'Die Buchhaltung nach Varianten für das Produkt kann nicht aktiviert werden.
						| Aktivieren Sie die Buchhaltung nach Varianten für die ausgewählte Produktkategorie.
						|Wählen Sie eine Produktkategorie mit der aktivierten Buchhaltung nach Varianten aus.
						|Um die Buchhaltung nach Varianten zu deaktivieren, deaktivieren Sie das Kontrollkästchen Varianten.'"),
					ThisObject, "UseCharacteristics", , Cancel);
				
			EndIf;
			
			If GetFunctionalOption("UseSerialNumbers")
				And UseSerialNumbers
				And Not ProductCategoryData.UseSerialNumbers Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot enable accounting by serial numbers for the product. Do one of the following:
						|• Enable accounting by serial numbers for the selected product category.
						|• Select a product category with accounting by serial numbers enabled.
						|• To disable accounting by serial numbers, clear the Serial numbers check box.'; 
						|ru = 'Не удается включить учет по серийным номерам для номенклатуры. Выполните следующие действия:
						|• Включить учет по серийным номерам для выбранной номенклатурной группы.
						|• Выберите номенклатурную группу с включенным учетом по серийным номерам.
						|• Чтобы отключить учет по серийным номерам, снимите флажок Серийные номера.';
						|pl = 'Nie można włączyć ewidencji według numerów seryjnych dla produktu. Wykonaj jedną z następujących czynności:
						|• Włącz ewidencję według numerów seryjnych dla wybranej kategorii produktów.
						|• Wybierz kategorie produktów z ewidencją według numerów seryjnych.
						|• Aby wyłączyć ewidencję według numerów seryjnych, odznacz pole wyboru Numery seryjne.';
						|es_ES = 'No se puede activar la contabilidad por números de serie del producto. Realice una de las siguientes acciones:
						|• Active la contabilidad por números de serie para la categoría de productos seleccionada.
						|• Seleccione una categoría de productos con la contabilidad por números de serie activada.
						|• Para desactivar la contabilidad por números de serie, desmarque la casilla de verificación Números de serie.';
						|es_CO = 'No se puede activar la contabilidad por números de serie del producto. Realice una de las siguientes acciones:
						|• Active la contabilidad por números de serie para la categoría de productos seleccionada.
						|• Seleccione una categoría de productos con la contabilidad por números de serie activada.
						|• Para desactivar la contabilidad por números de serie, desmarque la casilla de verificación Números de serie.';
						|tr = 'Ürün için seri numaralarına göre muhasebe etkinleştirilemiyor. Şunlardan birini deneyin:
						|• Seçili ürün kategorisi için seri numaralarına göre muhasebeyi etkinleştirin.
						|• Seri numaralarına göre muhasebenin etkinleştirildiği bir ürün kategorisi seçin.
						|• Seri numaralarına göre muhasebeyi devre dışı bırakmak için Seri numaraları onay kutusunu temizleyin.';
						|it = 'Impossibile attivare contabilità per numero di serie per l''articolo. Provare una delle seguenti operazioni:
						|• Attivare contabilità per numero di serie per la categoria di articolo selezionata.:
						|• Selezionare una categoria di articolo con contabilità per numero di serie attivata.:
						|• Per disattivare la contabilità per numero di serie, deselezionare la casella di controllo Numeri di serie.';
						|de = 'Die Buchhaltung nach Seriennummern für das Produkt kann nicht aktiviert werden.
						| Aktivieren Sie die Buchhaltung nach Seriennummern für die ausgewählte Produktkategorie.
						|Wählen Sie eine Produktkategorie mit der aktivierten Buchhaltung nach Seriennummern aus.
						|Um die Buchhaltung nach Seriennummern zu deaktivieren, deaktivieren Sie das Kontrollkästchen Seriennummern.'"),
					ThisObject, "UseSerialNumbers", , Cancel);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not VisibleToExternalUsers Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccessGroup");
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ChangeDate = CurrentSessionDate();
	
EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	If Not CopiedObject.IsFolder Then
		
		Specification				= Undefined;
		ProductCrossReference		= Undefined;
		UseDefaultCrossReference	= False;
		
		PictureFile = Catalogs.ProductsAttachedFiles.EmptyRef();
		
	EndIf;
	
	// Bundles
	IsBundle = False;
	BundlePricingStrategy = Enums.ProductBundlePricingStrategy.EmptyRef();
	BundleDisplayInPrintForms = Enums.ProductBundleDisplay.EmptyRef();
	// End Bundles
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	 
	If Not IsFolder Then
		
		ExpensesGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");
		InventoryGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Inventory");
		
		MeasurementUnit = DriveReUse.GetValueOfSetting("MainUnit");
		ReportUOM = MeasurementUnit;
		ConversionRate = 1;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Duplicate rules index
	If AdditionalProperties.Property("DuplicateRulesIndexTableAddress") Then
		DuplicateRulesIndexTable = GetFromTempStorage(AdditionalProperties.DuplicateRulesIndexTableAddress);
		AdditionalProperties.Insert("DuplicateRulesIndexTable", DuplicateRulesIndexTable);
	Else
		DuplicatesBlocking.PrepareDuplicateRulesIndexTable(Ref, AdditionalProperties);
	EndIf;
	
	If AdditionalProperties.Property("ModificationTableAddress") Then
		ModificationTable = GetFromTempStorage(AdditionalProperties.ModificationTableAddress);
		DuplicatesBlocking.ChangeDuplicatesData(ModificationTable, Cancel);
	EndIf;
	
	DriveServer.ReflectDuplicateRulesIndex(AdditionalProperties, Ref, Cancel);
	
	If DeletionMark Then
		
		DriveServer.CleanBarcodes(Ref);
		
	EndIf;
	
	// begin Drive.FullVersion
	Catalogs.CostObjects.UpdateLinkedCostObjectsData(Ref);
	// end Drive.FullVersion
	
EndProcedure

#EndRegion

#Region Private

Procedure OnReadPresentationsAtServer(Object) Export
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#EndIf