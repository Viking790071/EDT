#Region Public

// Allows you to change interface upon embedding.
//
// Parameters:
//  InterfaceSettings - Structure - contains a property:
//   * EnableExternalUsers - Boolean - (initial value is False) if you set to True, then period-end 
//     closing dates can be set up for external users.
//
Procedure InterfaceSetup(InterfaceSettings) Export
	
	PeriodClosingDatesDrive.InterfaceSetup(InterfaceSettings);
	
EndProcedure

// Fills in sections of period-end closing dates used upon their setup.
// If you do not specify any section, then only common period-end closing date setup will be available.
//
// Parameters:
//  Sections - ValueTable - with columns:
//   * Name - String - a name used in data source details in the 
//       FillDataSourcesForPeriodClosingCheck procedure.
//
//   * ID - UUID - an item reference ID of chart of characteristic types.
//       To get an ID, execute the platform method in 1C:Enterprise mode:
//       "ChartsOfCharacteristicTypes.PeriodClosingDatesSections.GetRef().UUID()".
//       Do not specify IDs received using any other method as it can violate their uniqueness.
//       
//
//   * Presentation - String - presents a section in the form of period-end closing date setup.
//
//   * ObjectsTypes - Array - object reference types, by which you can set period-end closing dates, 
//       for example, Type ("CatalogRef.Companies"), if no type is specified, then period-end 
//       closing dates are set up only to the precision of a section.
//
Procedure OnFillPeriodClosingDatesSections(Sections) Export
	
	PeriodClosingDatesDrive.OnFillChangeProhibitionDateSections(Sections);
	
EndProcedure

// Allows you to specify tables and object fields to check period-end closing.
// To add a new source to DataSources, see PeriodClosingDates.AddRow. 
//
// Called from the DataChangesDenied procedure of the PeriodClosingDates common module used in the 
// BeforeWrite event subscription of the object to check for period-end closing and canceled 
// restricted object changes.
//
// Parameters:
//  DataSources - ValueTable - with columns:
//   * Table - String - a full name of a metadata object, for example, "Metadata.Documents.
//                   PurchaseInvoice.FullName()".
//   * DataField    - String - a name of an object attribute or tabular section, for example: "Date", 
//                   "Goods.ShipmentDate".
//   * Section      - String - a name of a period-end closing date section specified in the 
//                   OnFillPeriodClosingDatesSections procedure (see above).
//   * ObjectField - String - a name of an object attribute or tabular section attribute, for 
//                   example: "Company", "Goods.Warehouse".
//
Procedure FillDataSourcesForPeriodClosingCheck(DataSources) Export
	
	PeriodClosingDatesDrive.FillDataSourcesForPeriodEndClosingCheck(DataSources);
	
EndProcedure

// Allows you to arbitrarily override period-end closing check:
//
// If you check upon writing the document, the AdditionalProperties property of the Object document 
// contains the WriteMode property.
//  
// Parameters:
//  Object - CatalogObject,
//                 DocumentObject,
//                 ChartOfCharacteristicTypesObject,
//                 ChartOfAccountsObject,
//                 ChartOfCalculationTypesObject,
//                 BusinessProcessObject,
//                 TaskObject,
//                 ExchangePlanObject,
//                 InformationRegisterRecordSet,
//                 AccumulationRegisterRecordSet,
//                 AccountingRegisterRecordSet,
//                 CalculationRegisterRecordSet - a data item or a record set to be checked (passed 
//                 from handlers BeforeWrite and OnReadAtServer).
//
//  PeriodClosingCheck - Boolean - set to False to skip period-end closing check.
//  ImportRestrictionCheckNode - ExchangePlansRef, Undefined - set to Undefined to skip data import 
//                                restriction check.
//  ObjectVersion - String - set "OldVersion" or "NewVersion" to check only the old object version 
//                                (in the database) or only the new object version (in the Object 
//                                parameter).
//                                By default, contains the "" value - both object versions are checked at the same time.
//
Procedure BeforeCheckPeriodClosing(Object,
                                         PeriodClosingCheck,
                                         ImportRestrictionCheckNode,
                                         ObjectVersion) Export
	
	
	
EndProcedure

#EndRegion
