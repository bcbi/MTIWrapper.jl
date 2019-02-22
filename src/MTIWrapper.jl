module MTIWrapper

# export  install_web_api,
#         generic_batch,
#         abstracts_to_request_file,
#         parse_and_save_default_MTI,
#         parse_and_save_MoD

# using BioMedQuery.Entrez.DB
# using BioMedQuery.DBUtils


# function mti_search_and_save(config, main_func = parse_and_save_default_MTI;
#                                 append_results=false, verbose= false,
#                                 num_cols = 8, num_cols_prc = 4,
#                                 uid_column::Symbol = :pmid)

#     println("*-------------This is: mti_search_and_save-------------------*")

#     # make sure all keys are present
#     keys = [:email, :db, :pub_year, :mti_query_file, :mti_result_file]

#     if reduce(+, map(x -> haskey(config, x), keys)) != length(keys)
#     error("Incorrect configuration for mti_search_and_save")
#     end

#     # easy refernces
#     email = config[:email]
#     username = config[:uts_user]
#     password = config[:uts_psswd]
#     db = config[:db]
#     pub_year = config[:pub_year]
#     mti_query_file = config[:mti_query_file]
#     mti_result_file = config[:mti_result_file]

#     use_local_medline = false
#     if haskey(config, :local_medline)
#     use_local_medline = config[:local_medline]
#     end


#     # write abstracts to quey file
#     abstracts_to_request_file(db, pub_year, mti_query_file;
#         local_medline = use_local_medline,
#         uid_column = uid_column)

#     # submit query file to batch processing
#     generic_batch(email, username, password, mti_query_file, mti_result_file)

#     #save to Database
#     main_func(mti_result_file, db; num_cols = num_cols, num_cols_prc = num_cols_prc,
#     append_results=append_results, verbose= verbose,
#     uid_column = uid_column)

# end

"""
    function install_web_api(root_dir)
Installs MTI Java jar to specified location
"""
function install_web_api(root_dir)

    if !isdir(root_dir)
        mkdir(root_dir)
    else
        rm(root_dir, recursive = true, force = true)
        mkdir(root_dir)
    end


    println("Dowloading fresh copy of sources")
    # get sources and expand
    download("https://ii.nlm.nih.gov/Web_API/SKR_Web_API_V2_3.jar", "$root_dir/SKR_Web_API_V2_3.jar")
    run(`java sun.tools.jar.Main xf $root_dir/SKR_Web_API_V2_3.jar`)

    # compile
    cd("SKR_Web_API_V2_3")
    run(`chmod +x ./compile.sh ./run.sh ./build.sh`)
    run(`./compile.sh ../../GenericBatchCustom.java`)

end

"""
    function mti_batch_query(mti_java_dir, email, username, password, in_file, out_file)
Send a batch query to MTI. Use function `abstracts_to_request_file` to generate `in_file`
"""
function mti_batch_query(mti_java_dir, email, username, password, in_file, out_file)
    cwd= dirname(@__FILE__)
    run(`$cwd/generic_batch.sh $mti_java_dir $email $username $password $in_file $out_file`)
end


"""
    abs_to_request_file(pub_year)

Write all abstracts in a year, to a file to be used for MTI batch query.
The format is:

UI - pmid
AB - abstract_text
"""
function abstracts_to_request_file(db, pub_year, out_file;
                                   local_medline = false,
                                   uid_column::Symbol = :pmid)

    abs_sel = abstracts_by_year(db, pub_year; local_medline = local_medline, uid_str = string(uid_column))

    #call MTI
    open(out_file, "w") do file

        for i=1:size(abs_sel)[1]
            uid = abs_sel[i, uid_column]
            abstract_text = abs_sel[i, :abstract_text]

            if isna(abstract_text)
                println( "Skipping empty abstract for PMID: ", uid)
                continue
            end

            # convert to ascii - all unicode caracters to " "
            abstract_ascii = replace(abstract_text, r"[^\u0000-\u007F]", " ")
            write(file, "UI  - $uid \n")
            write(file, "AB  - $abstract_ascii \n \n")
        end
    end

end

# function parse_and_save_MoD(file, db; num_cols = 9, num_cols_prc = 4, append_results=false, verbose= false)
#     mesh_lines, prc_lines = parse_result_file(file, num_cols, num_cols_prc)
#     println("Saving ", length(mesh_lines), " mesh entries")
#     save_MoD(db, mesh_lines, prc_lines; append_results=append_results, verbose= verbose)
# end

# function parse_and_save_default_MTI(file, db; num_cols = 8, num_cols_prc = 4,
#                                     append_results=false, verbose= false,
#                                     uid_column::Symbol = :pmid)
#     mesh_lines, prc_lines = parse_result_file(file, num_cols, num_cols_prc)
#     println("Saving ", length(mesh_lines), " mesh entries")
#     save_default_MTI(db, mesh_lines; append_results=append_results, verbose= verbose, uid_column = uid_column)
# end


function parse_result_file(file, num_cols = 8, num_cols_prc = 10000)
    mesh_lines = []
    prc_lines =[]
    open(file, "r") do f
        lines = eachline(f)
        for line in lines
            entries = split(chomp(line), "|")
            if length(entries) == num_cols
                push!(mesh_lines, entries)
            elseif length(entries) == num_cols_prc
                push!(prc_lines, entries)
            else
                warn("Parsing MTI results - unexpected number of entries per line")
                println(line)
            end
        end
    end
    return mesh_lines, prc_lines
end

# function init_MoD_tables(db, append_results = false)

#     query_str ="CREATE TABLE IF NOT EXISTS mti (
#                     term VARCHAR(255),
#                     dui INT,
#                     pmid INT,
#                     cui INT,
#                     score INT,
#                     term_type CHAR(2),

#                     PRIMARY KEY(pmid, term)
#                 );
#                 CREATE TABLE IF NOT EXISTS mti_prc  (
#                                 pmid INT,
#                                 prc_pmid INT,

#                                 PRIMARY KEY(pmid, prc_pmid)
#                  );
#                  "


#     # FOREIGN KEY (term, dui)
#     #   REFERENCES mesh_descriptor(name, id),
#     db_query(db, query_str)

#     #clear the relationship table
#     if !append_results
#         db_query(db, "DELETE FROM mti")
#     end
# end


# function init_default_MTI_tables(db; append_results = false, uid_column::Symbol = :pmid)

#     uid_column_name = string(uid_column)
#     query_str ="CREATE TABLE IF NOT EXISTS mti (
#                     term VARCHAR(255),
#                     dui INT,
#                     $uid_column_name INT,
#                     cui INT,
#                     score INT,
#                     term_type CHAR(2),

#                     PRIMARY KEY($uid_column_name, term)
#                 );
#                 "


#     # FOREIGN KEY (term, dui)
#     #   REFERENCES mesh_descriptor(name, id),
#     db_query(db, query_str)

#     #clear the relationship table
#     if !append_results
#         db_query(db, "DELETE FROM mti")
#     end
# end
# function save_MoD(db, mesh_lines, prc_lines; append_results=false, verbose= false)
#     init_MoD_tables(db, append_results)

#     for ml in mesh_lines

#         dui = parse(Int64, ml[9][2:end])  #remove preceding D
#         cui = parse(Int64, ml[3][2:end])  #remove preceding C

#         insert_row!(db, "mti",
#                     Dict(:pmid =>ml[1],
#                          :term => ml[2],
#                          :cui=>cui,
#                          :score=>ml[4],
#                          :term_type=> ml[5],
#                          :dui=>dui), verbose)

#     end

#     for prc in prc_lines
#         prc_pmids = split(prc[3], ';')
#         for id in prc_pmids
#             insert_row!(db, "mti_prc",
#                         Dict(:pmid =>prc[1],
#                              :prc_pmid=>id), verbose)
#         end
#     end

# end


# function save_default_MTI(db, mesh_lines; append_results=false, verbose= false,
#                           uid_column::Symbol = :pmid)

#     init_default_MTI_tables(db, append_results = append_results, uid_column = uid_column)

#     for ml in mesh_lines

#         cui = 0

#         try
#           cui = parse(Int64, ml[3][2:end], 10)  #remove preceding C
#         catch
#           warn("Could not parse CUI field: ", ml[3][2:end])
#           println("Line: ", ml)
#         end

#         insert_row!(db, "mti",
#                     Dict(uid_column =>ml[1],
#                          :term => ml[2],
#                          :cui=>cui,
#                          :score=>ml[4],
#                          :term_type=> ml[5]), verbose)

#     end

# end


end # module
