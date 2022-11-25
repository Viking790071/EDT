#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.ManufacturingOverheadsRates.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectPredeterminedOverheadRates(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ManufacturingOverheadsAllocationMethod = Enums.ManufacturingOverheadsAllocationMethods.ActivityBasedCosting Then
		
		CheckedAttributes.Add("Rates.Activity");
		
	ElsIf ManufacturingOverheadsAllocationMethod = Enums.ManufacturingOverheadsAllocationMethods.DepartmentalAllocation Then
		
		CheckedAttributes.Add("Rates.BusinessUnit");
		
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		
		Result = CheckCountGLAToExpenseItem();
		If Result.Error Then
			MessageHeadText = NStr("en = 'Cannot save the document.'; ru = 'Не удалось записать документ.';pl = 'Nie można zapisać dokumentu.';es_ES = 'No se ha podido guardar el documento.';es_CO = 'No se ha podido guardar el documento.';tr = 'Belge kaydedilemiyor.';it = 'Impossibile salvare il documento.';de = 'Fehler beim Speichern des Dokuments.'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageHeadText);
				
			For Each Item In Result.ExpenseItems Do
				MessageText = NStr("en = 'On the Rates tab, different GL accounts are specified for the same expense item ""%1"".
									|Specify the same GL accounts. Then try again.'; 
									|ru = 'На вкладке ""Ставки"" для одной и той же статьи расходов ""%1"" указаны разные счета учета.
									|Укажите одинаковые счета учета и попробуйте снова.';
									|pl = 'Na karcie Stawki, różne konta księgowe są określone dla tej samej pozycji rozchodów ""%1"".
									|Określ te same konta księgowe. Następnie spróbuj ponownie.';
									|es_ES = 'En la pestaña Tasas, se especifican diferentes cuentas del libro mayor para el mismo artículo de gastos ""%1"".
									|Especifique las mismas cuentas del libro mayor. A continuación, inténtelo de nuevo.';
									|es_CO = 'En la pestaña Tasas, se especifican diferentes cuentas del libro mayor para el mismo artículo de gastos ""%1"".
									|Especifique las mismas cuentas del libro mayor. A continuación, inténtelo de nuevo.';
									|tr = 'Oranlar sekmesinde aynı ""%1"" gider kalemi için farklı muhasebe hesapları belirtilmiş.
									|Aynı muhasebe hesaplarını belirtip tekrar deneyin.';
									|it = 'Nella scheda Tassi, sono indicati diversi conti mastro per la stessa voce di uscita ""%1"".
									|Indicare gli stessi conti mastro, poi riprovare.';
									|de = 'Verschiedene Hauptbuch-Konten sind auf der Registerkarte Raten für dieselbe Position der Ausgaben ""%1"" eingegeben.
									|Geben Sie dieselbe Hauptbuch-Konten ein. Dann versuchen Sie erneut.'");
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(MessageText, Item),
					,
					,
					,
					Cancel);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function CheckCountGLAToExpenseItem()
	
	Result = New Structure("Error,ExpenseItems", False, New Array);
	
	ExpenseItemTable = Rates.Unload(, "GLAccount,ExpenseItem");
	ExpenseItemTable.GroupBy("ExpenseItem,GLAccount");
	GLACount = ExpenseItemTable.Count();
	
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescriptionN = New TypeDescription(Array, , ,New NumberQualifiers(10,0));
	ExpenseItemTable.Columns.Add("GLACount", TypeDescriptionN);
	
	For Each Row In ExpenseItemTable Do
		Row.GLACount = 1;
	EndDo;
	
	ExpenseItemTable.GroupBy("ExpenseItem", "GLACount");
	ExpenseItemCount = ExpenseItemTable.Count();
	
	Result.Error = ExpenseItemCount < GLACount;
	If Result.Error Then
		For Each Row In ExpenseItemTable Do
			If Row.GLACount > 1 Then
				Result.ExpenseItems.Add(Row.ExpenseItem);
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf