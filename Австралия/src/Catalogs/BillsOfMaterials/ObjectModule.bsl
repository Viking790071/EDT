#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not UseRouting Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Content.Activity");
	EndIf;
	
	EnimStatusActive = Enums.BOMStatuses.Active;
	
	If Status = EnimStatusActive Then
		
		If Content.Count() = 0 Then
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				NStr("en = 'Fill the components table.'; ru = 'Заполните таблицу сырья и материалов.';pl = 'Wypełnij tabelę komponentów';es_ES = 'Rellenar la tabla de componentes.';es_CO = 'Rellenar la tabla de componentes.';tr = 'Malzeme tablosunu doldurun.';it = 'Compilare la tabella delle componenti.';de = 'Die Materialbestand-Tabelle ausfüllen.'"),
				"Content",
				1,
				"Products",
				Cancel);
			Return;
			
		EndIf;
		
		HasErrors = False;
		
		For Each LineContent In Content Do
		
			If LineContent.ManufacturedInProcess And Not ValueIsFilled(LineContent.Specification) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'The BOM has to be filled for component with ''Produce'' mark.'; ru = 'Необходимо заполнить спецификацию для компонента с отметкой ''Производство''.';pl = 'Specyfikacja materiałowa powinna być wypełniona komponentem według znaku ""Produkuj"".';es_ES = 'La lista de materiales tiene que ser rellenada para el componente con la marca ""Producir"".';es_CO = 'La lista de materiales tiene que ser rellenada para el componente con la marca ""Producir"".';tr = '""Mamul"" işaretli bileşen için ürün reçetesinin doldurulması gerekli.';it = 'La distinta base deve essere compilata per la componente con contrassegno ""Produrre"".';de = 'Die Stückliste muss für Komponente mit ''Herstellen'' -Markierung ausgefüllt werden.'"),
					"Content",
					LineContent.LineNumber,
					"Specification",
					Cancel);
					
				HasErrors = True;
				
			EndIf;
				
			If ValueIsFilled(LineContent.Specification) Then
				
				StructureSpecification = Common.ObjectAttributesValues(LineContent.Specification,
					"Status, ValidityStartDate, ValidityEndDate");
			
				If Not StructureSpecification.Status = EnimStatusActive Then
					
					TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The component in line #%1 belongs to an inactive BOM. Please select an active BOM.'; ru = 'Сырье и материалы в строке %1 относятся к неактивной спецификации. Выберите активную спецификацию.';pl = 'Element w wierszu nr%1 należy do nieaktywnej specyfikacji materiałowej. Wybierz aktywną specyfikację materiałową.';es_ES = 'El componente en la línea #%1 pertenece a un inactivo BOM. Por favor, seleccione un activo BOM.';es_CO = 'El componente en la línea #%1 pertenece a un inactivo BOM. Por favor, seleccione un activo BOM.';tr = '#%1 satırındaki malzeme aktif olmayan bir ürün reçetesine ait. Lütfen, aktif bir ürün reçetesi seçin.';it = 'La componente nella riga #%1 appartiene a una distinta base inattiva. Selezionare una distinta base attiva.';de = 'Die Komponente in der Zeile Nr %1 gehört zu einer nicht aktiven Stückliste. Wählen Sie bitte eine aktive Stückliste.'"),
						TrimAll(LineContent.LineNumber));
						
					DriveServer.ShowMessageAboutError(
						ThisObject,
						TextMessage,
						"Content",
						LineContent.LineNumber,
						"Specification",
						Cancel);
						
					HasErrors = True;
						
				EndIf;
					
				IsPeriodError = False;
				If ValueIsFilled(StructureSpecification.ValidityEndDate)
					And ValidityEndDate > StructureSpecification.ValidityEndDate Then
						
					IsPeriodError = True;
						
					HasErrors = True;
						
				EndIf;
					
				If ValueIsFilled(StructureSpecification.ValidityStartDate)
					And StructureSpecification.ValidityStartDate > ValidityStartDate Then
						
					IsPeriodError = True;
						
					HasErrors = True;
						
				EndIf;
				
				If IsPeriodError Then
					
					TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'A component in line #%1 has BOM with validity period that is shorter than the validity period of this BOM. 
							|Select the component BOM with the validity period matching or longer than the validity period of this BOM.'; 
							|ru = 'Компонент в строке %1 имеет спецификацию, срок действия которой короче срока действия этой спецификации. 
							|Выберите спецификацию компонента со сроком действия, который будет длиннее или совпадать со сроком действия этой спецификации.';
							|pl = 'Komponent w wierszu #%1 ma specyfikację materiałową z okresem ważności, krótszym niż okres ważności tej specyfikacji materiałowej. 
							|Wybierz specyfikację materiałową z okresem ważności odpowiadającym lub dłuższym niż okres ważności tej specyfikacji materiałowej.';
							|es_ES = 'Un componente en la línea #%1tiene una lista de materiales con un período de validez más corto que el de esta lista de materiales. 
							|Seleccione la lista de materiales del componente con el período de validez que coincida o sea más largo que el período de validez de esta lista de materiales.';
							|es_CO = 'Un componente en la línea #%1tiene una lista de materiales con un período de validez más corto que el de esta lista de materiales. 
							|Seleccione la lista de materiales del componente con el período de validez que coincida o sea más largo que el período de validez de esta lista de materiales.';
							|tr = 'No%1 satırındaki bileşenin ürün reçetesinin geçerlilik dönemi bu ürün reçetesinin geçerlilik döneminden kısa.
							|Ürün reçetesinin geçerlilik dönemi bu ürün reçetesinin geçerlilik dönemine uyan veya daha uzun olan bir bileşen seçin.';
							|it = 'Una componente nella riga #%1 possiede una distinta base con periodo di validità minore del periodo di validità di questa distinta base. 
							|Selezionare la distinta base componente con periodo di validità corrispondente o maggiore del periodo di validità di questa distinta base.';
							|de = 'Die Komponente in der Zeile Nr.%1 hat eine Stückliste mit einer Gültigkeitsdauer weniger als die Gültigkeitsdauer der Stückliste. 
							|Wählen Sie die Stücklistenkomponente mit derselben oder längerer Gültigkeitsdauer, als diese Stückliste aus.'"),
						TrimAll(LineContent.LineNumber));
						
					DriveServer.ShowMessageAboutError(
						ThisObject,
						TextMessage,
						"Content",
						LineContent.LineNumber,
						"Specification",
						Cancel);
						
					HasErrors = True;
					
				EndIf;
					
			EndIf;
			
			If UseRouting Then
				
				If Operations.Count() = 0 Then
				
					DriveServer.ShowMessageAboutError(
						ThisObject,
						NStr("en = 'Fill the routing table.'; ru = 'Заполните таблицу маршрутов.';pl = 'Wypełnij tablicę marszrut.';es_ES = 'Rellenar la tabla de rutas.';es_CO = 'Rellenar la tabla de rutas.';tr = 'Rota tablosunu doldurun.';it = 'Compilare la tabella di percorso.';de = 'Die Routing-Tabelle ausfüllen'"),
						"Operations",
						1,
						"Activity",
						Cancel);
				
				IsReturn = True;
				
			EndIf;

			If Not ValidityEndDate = Date(1,1,1) 
				And BegOfDay(ValidityStartDate) > BegOfDay(ValidityEndDate) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'Date ""valid from"" more that date ""valid to"".'; ru = 'Дата в графе ""срок действия с"" превышает дату в графе ""срок действия до"".';pl = 'Data „ważna od” większa, niż data „ważna do”.';es_ES = 'La fecha ""válida desde"" más la fecha ""válida hasta"".';es_CO = 'La fecha ""válida desde"" más la fecha ""válida hasta"".';tr = '''''Geçerlilik başlangıcı'''' tarihi ''''Geçerlilik sonu'''' tarihinden ileri.';it = 'Data ""Valido da"" successiva alla data ""Valido fino"".';de = 'Das Datum ""gültig ab"" liegt nach dem Datum ""gültig bis"".'"),
					,
					,
					"ValidityStartDate",
					Cancel);
					
				HasErrors = True;
				
			EndIf;
			
		EndIf;
		
		EndDo;
		
		For Each OperationsLine In Operations Do
			
			If ValueIsFilled(OperationsLine.StandardTimeInUOM) And Not ValueIsFilled(OperationsLine.TimeUOM) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'Time unit is required on Operation tab.'; ru = 'Укажите единицу времени на вкладке ""Операция"".';pl = 'Jednostka czasu jest wymagana na karcie Operacja.';es_ES = 'Se requiere la unidad de tiempo en la pestaña Operación.';es_CO = 'Se requiere la unidad de tiempo en la pestaña Operación.';tr = 'İşlem sekmesinde zaman ölçü birimi gerekli.';it = 'È richiesta l''unità di tempo nella scheda Operazione.';de = 'In der Registerkarte Operation ist Zeiteinheit benötigt.'"),
					"Operations",
					OperationsLine.LineNumber,
					"TimeUOM",
					Cancel);
					
				HasErrors = True;
				
			EndIf;
			
		EndDo;
		
		For Each OperationsLine In Operations Do
			
			If ValueIsFilled(OperationsLine.StandardTimeInUOM) And Not ValueIsFilled(OperationsLine.TimeUOM) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'Time unit is required on Operation tab.'; ru = 'Укажите единицу времени на вкладке ""Операция"".';pl = 'Jednostka czasu jest wymagana na karcie Operacja.';es_ES = 'Se requiere la unidad de tiempo en la pestaña Operación.';es_CO = 'Se requiere la unidad de tiempo en la pestaña Operación.';tr = 'İşlem sekmesinde zaman ölçü birimi gerekli.';it = 'È richiesta l''unità di tempo nella scheda Operazione.';de = 'In der Registerkarte Operation ist Zeiteinheit benötigt.'"),
					"Operations",
					OperationsLine.LineNumber,
					"TimeUOM",
					Cancel);
					
				HasErrors = True;
				
			EndIf;
			
		EndDo;
		
		If Operations.Count() Then
			
			DifferentDepartmentsMessage = Catalogs.BillsOfMaterials.CheckOperationsTableForDifferentDepartments(Operations.Unload(,"LineNumber, Activity"));
			If DifferentDepartmentsMessage <> "" Then
				
				HasErrors = True;
				
				ErrorMessageTemplate = NStr("en = 'Couldn''t save BOM ""%1"". Its operations are assigned with work center types that belong to different business units:'; ru = 'Не удалось сохранить спецификацию ""%1"". Ее операции назначены типам рабочих центров, входящим в разные подразделения:';pl = 'Nie udało się zapisać specyfikacji materiałowej ""%1"". Operacje z niej są przypisane do typów gniazd produkcyjnych, które należą do różnych jednostek biznesowych:';es_ES = 'No se pudo guardar la lista de materiales ""%1"". Sus operaciones están asignadas con tipos de centros de trabajo que pertenecen a diferentes unidades empresariales:';es_CO = 'No se pudo guardar la lista de materiales ""%1"". Sus operaciones están asignadas con tipos de centros de trabajo que pertenecen a diferentes unidades empresariales:';tr = '""%1"" ürün reçetesi kaydedilemedi. İşlemleri, farklı departmanlara ait iş merkezi türleriyle atanmış:';it = 'Impossibile salvare la distinta base ""%1"". Le sue operazioni sono assegnate con tipi di centro di lavoro che appartengono a diverse business unit:';de = 'Fehler beim Speichern einer Stückliste ""%1"". Deren Operationen sind den Typen von Arbeitsabschnitten zugewiesen, die zu verschiedenen Abteilungen gehören:'");
				
				ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, Description);
				
				ErrorMessage = ErrorMessage
					+ DifferentDepartmentsMessage
					+ NStr("en = 'Please select operations assigned with work center types that belong to the same business units.'; ru = 'Выберите операции, назначенные типам рабочих центров, входящим в одно подразделение.';pl = 'Wybierz operacje przypisane do typów gniazd produkcyjnych, które należą do tych samych jednostek biznesowych.';es_ES = 'Por favor, seleccione las operaciones asignadas con tipos de centros de trabajo que pertenezcan a las mismas unidades empresariales.';es_CO = 'Por favor, seleccione las operaciones asignadas con tipos de centros de trabajo que pertenezcan a las mismas unidades empresariales.';tr = 'Lütfen, aynı departmanlara ait iş merkezi türleriyle atanmış işlemler seçin.';it = 'Selezionare le operazioni assegnate con i tipi di centro di lavoro che appartengono alla stessa business unit.';de = 'Bitte wählen Sie die den Typen von Arbeitsabschnitten zugewiesenen Operationen aus, die zu verschiedenen Abteilungen gehören.'");
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					ErrorMessage,
					,
					,
					,
					Cancel);
			
			EndIf;
			
		EndIf;
		
		If HasErrors Then
			Return;
		EndIf;
		
	EndIf;
		
	If Status = Enums.BOMStatuses.Open 
		Or Status = Enums.BOMStatuses.Closed Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Quantity");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Content.ContentRowType");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Content.Products");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Content.MeasurementUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Content.Quantity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Content.Activity");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Operations.Activity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Operations.Quantity");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ByProducts.Quantity");
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	If Status = Enums.BOMStatuses.Closed
		And Ref.Status <> Status Then
		ValidityEndDate = CurrentSessionDate();
	EndIf;
	
	If Status = Enums.BOMStatuses.Active
		And (IsNew() Or Ref.Status = Enums.BOMStatuses.Open) Then
		
		AdditionalProperties.Insert("CreateNewHierarchy", True);
		
	EndIf;
	
	If DeletionMark And Not Ref.DeletionMark Then
		
		AdditionalProperties.Insert("ClearBOMHierarchy", True);
		
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	Status = Enums.BOMStatuses.Open;
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		If FillingData.Property("OperationKind") And ValueIsFilled(FillingData.OperationKind) Then
			
			OperationKind = FillingData.OperationKind;
			
		ElsIf FillingData.Property("Owner") And ValueIsFilled(FillingData.Owner) Then
			
			ReplenishmentMethod = Common.ObjectAttributeValue(FillingData.Owner, "ReplenishmentMethod");
			
			If ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
				Or ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing Then
				OperationKind = Enums.OperationTypesProductionOrder.Production;
			ElsIf ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
				OperationKind = Enums.OperationTypesProductionOrder.Assembly;
			EndIf;
			
		EndIf;
		
		If OperationKind = Enums.OperationTypesProductionOrder.Production Then
			UseRouting = True;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If Status = Enums.BOMStatuses.Active Then
		Catalogs.BillsOfMaterials.CheckLooping(Ref, Cancel);
		If Not Cancel Then
			Catalogs.BillsOfMaterials.CheckBOMLevel(Ref, Cancel);
		EndIf;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("ClearBOMHierarchy") And AdditionalProperties.ClearBOMHierarchy Then
		Catalogs.BillsOfMaterialsHierarchy.ClearBOMHierarchy(Ref);
	EndIf;
	
	If AdditionalProperties.Property("CreateNewHierarchy") And AdditionalProperties.CreateNewHierarchy Then
		Catalogs.BillsOfMaterialsHierarchy.CreateNewHierarchy(Ref);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf