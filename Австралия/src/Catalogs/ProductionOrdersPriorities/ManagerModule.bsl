#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function DefaultPriority() Export
	
	Return Constants.DefaultProductionOrdersPriority.Get();
	
EndFunction

Procedure FillPredefinedProductionOrdersPriorities() Export
	
	// Low
	FillPredefinedPriority("Low", 5);
	
	// Medium
	FillPredefinedPriority("Medium", 3, True);
	
	// High
	FillPredefinedPriority("High", 1);
	
EndProcedure

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Order");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ProductionOrdersPriorities);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillPredefinedPriority(ItemName, Order, IsDefault = False)
	
	MediumPriority = Catalogs.ProductionOrdersPriorities[ItemName];
	If Common.ObjectAttributeValue(MediumPriority, "Order") = 0 Then
		
		MediumPriorityObject = MediumPriority.GetObject();
		MediumPriorityObject.Active = True;
		MediumPriorityObject.Order = Order;
		
		Try
			
			InfobaseUpdate.WriteObject(MediumPriorityObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				MediumPriority,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.ProductionOrdersPriorities,
				,
				ErrorDescription);
				
		EndTry;
		
		If IsDefault Then
			
			// Set as default
			Try
				
				Constants.DefaultProductionOrdersPriority.Set(MediumPriority);
				
			Except
				
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save constant ""Default production orders priority"". Details: %1'; ru = 'Не удалось записать константу ""Приоритет заказов на производство по умолчанию"". Подробнее: %1';pl = 'Nie można zapisać stałej ""Domyślny priorytet zleceń produkcyjnych"". Szczegóły: %1';es_ES = 'Ha ocurrido un error al guardar la constante ""Prioridad de las órdenes de producción por defecto"". Detalles %1';es_CO = 'Ha ocurrido un error al guardar la constante ""Prioridad de las órdenes de producción por defecto"". Detalles %1';tr = '""Varsayılan üretim emirleri önceliği"" sabiti kaydedilemiyor. Ayrıntılar: %1';it = 'Impossibile salvare la costante ""Priorità di default ordine di produzione"". Dettagli: %1';de = 'Fehler beim Speichern der Konstante ""Standard-Priorität von Produktionsaufträgen"". Details: %1'",
						CommonClientServer.DefaultLanguageCode()),
					BriefErrorDescription(ErrorInfo()));
					
				WriteLogEvent(
					InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,
					Metadata.Constants.DefaultProductionOrdersPriority,
					,
					ErrorDescription);
					
			EndTry;
		
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
