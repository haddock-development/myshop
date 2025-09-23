#!/bin/bash

# Content Automation for WooCommerce
# CSV Import, Product Generation, Content Management
# Usage: ./content-automation.sh [command] [options]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${CYAN}🤖 $1${NC}"
}

# Docker / WordPress configuration
DOCKER_BIN="/Applications/Docker.app/Contents/Resources/bin/docker"
WP_SERVICE="wpcli"
WP_PATH="/var/www/html/web/wp"
WP_USER="1"

IMPORT_DIR="content-imports"
EXPORT_DIR="content-exports"
SAMPLES_DIR="sample-data"

mkdir -p "$IMPORT_DIR" "$EXPORT_DIR" "$SAMPLES_DIR"

docker_compose() {
    "$DOCKER_BIN" compose "$@"
}

run_wp() {
    docker_compose run --rm "$WP_SERVICE" --path="$WP_PATH" --user="$WP_USER" "$@"
}

check_wordpress() {
    local running
    running=$(docker_compose ps --status running --services 2>/dev/null || true)

    if ! grep -q '^php$' <<<"$running"; then
        print_error "WordPress containers are not running"
        echo "Run: $DOCKER_BIN compose up -d"
        return 1
    fi

    if ! grep -q '^db$' <<<"$running"; then
        print_error "Database container is not running"
        echo "Run: $DOCKER_BIN compose up -d"
        return 1
    fi
}

generate_sample_csv() {
    print_header "Generating Sample Product CSV"

    local csv_file="$SAMPLES_DIR/sample-products.csv"

    cat > "$csv_file" << 'EOFCSV'
name,type,regular_price,sale_price,description,short_description,stock_quantity,weight,length,width,height,categories,tags,images
"Premium T-Shirt",simple,29.99,24.99,"Hochwertiges Premium T-Shirt aus 100% Bio-Baumwolle. Perfekt für den Alltag und besondere Anlässe.","Nachhaltiges T-Shirt aus Bio-Baumwolle",50,0.2,30,25,2,"Kleidung,T-Shirts","Bio,Premium,Nachhaltig",""
"Gaming Maus",simple,89.99,,"Professionelle Gaming-Maus mit RGB-Beleuchtung und 12 programmierbaren Tasten.","High-End Gaming-Maus für Profis",25,0.15,12,7,4,"Elektronik,Gaming","Gaming,RGB,Wireless",""
"Kaffeetasse Set",simple,19.99,14.99,"Elegantes Kaffeetassen-Set aus Porzellan. 4 Tassen mit passenden Untertassen.","Porzellan Kaffeetassen Set - 4-teilig",100,1.2,25,25,15,"Haushalt,Küche","Porzellan,Set,Kaffee",""
"Yoga Matte Premium",simple,49.99,39.99,"Rutschfeste Yoga-Matte aus natürlichem Kautschuk. Ideal für alle Yoga-Arten.","Eco-friendly Yoga Matte",30,1.8,180,60,0.6,"Sport,Yoga","Yoga,Eco,Fitness",""
"Digital E-Book",simple,9.99,,"Umfassendes E-Book über digitales Marketing. Sofortiger Download nach Kauf.","Marketing E-Book - Digitaler Download",,,,,"Bücher,Digital","E-Book,Marketing,Digital",""
"Bluetooth Kopfhörer",simple,159.99,129.99,"Kabellose Over-Ear Kopfhörer mit Active Noise Cancelling und 30h Akkulaufzeit.","Premium Bluetooth Kopfhörer mit ANC",15,0.25,20,18,8,"Elektronik,Audio","Bluetooth,ANC,Premium",""
"Bio Honig 500g",simple,12.99,,"Naturbelassener Bio-Honig aus lokaler Imkerei. Cremige Konsistenz und milder Geschmack.","Bio Honig aus regionaler Imkerei",75,0.5,8,8,12,"Lebensmittel,Bio","Bio,Honig,Regional",""
"Fitness Tracker",simple,199.99,179.99,"Smartwatch mit Fitness-Tracking, Herzfrequenzmesser und GPS. Wasserdicht bis 50m.","Fitness Smartwatch mit GPS",20,0.05,4,4,1,"Elektronik,Fitness","Fitness,GPS,Smartwatch",""
EOFCSV

    print_success "Sample CSV created: $csv_file"
    echo
    echo "📋 Contains 8 sample products"
    echo "🚀 Import with: ./content-automation.sh import-csv $csv_file"
}

import_csv() {
    local csv_file="${1:-}"

    if [[ -z "$csv_file" ]]; then
        print_error "No CSV file specified"
        echo "Usage: ./content-automation.sh import-csv path/to/file.csv"
        return 1
    fi

    if [[ ! -f "$csv_file" ]]; then
        print_error "CSV file not found: $csv_file"
        return 1
    fi

    check_wordpress

    print_header "Importing Products from CSV"
    print_status "File: $csv_file"

    local total_products
    total_products=$(($(wc -l < "$csv_file") - 1))
    print_status "Products to import: $total_products"

    print_status "Starting import process..."

    if ! run_wp wc product import "$csv_file" >/dev/null; then
        print_error "CSV import failed"
        return 1
    fi

    print_success "CSV import completed"
    show_product_summary
}

export_csv() {
    local output_file="${1:-$EXPORT_DIR/products-export-$(date +%Y%m%d-%H%M%S).csv}"

    check_wordpress

    print_header "Exporting Products to CSV"
    print_status "Output: $output_file"

    mkdir -p "$(dirname "$output_file")"

    if run_wp wc product list \
        --format=csv \
        --fields=id,name,type,regular_price,sale_price,description,short_description,stock_quantity \
        > "$output_file"; then
        local count
        count=$(wc -l < "$output_file")
        print_success "Exported $((count - 1)) products to: $output_file"
    else
        print_error "Export failed"
        return 1
    fi
}

create_products_from_templates() {
    local count="$1"
    shift
    local -a templates=("$@")
    local created=0

    for template in "${templates[@]}"; do
        if (( created >= count )); then
            break
        fi

        IFS=':' read -r name price desc short stock weight <<< "$template"
        print_status "Creating: $name"

        run_wp wc product create \
            --name="$name" \
            --type=simple \
            --regular_price="$price" \
            --description="$desc" \
            --short_description="$short" \
            --status=publish \
            --stock_quantity="$stock" \
            --manage_stock=true \
            --weight="$weight" \
            >/dev/null 2>&1

        created=$((created + 1))
    done

    print_success "Generated $created products"
}

generate_products() {
    local category="${1:-}"
    local count="${2:-5}"

    if [[ -z "$category" ]]; then
        print_error "Category required"
        echo "Available categories: elektronik, kleidung, haushalt, sport"
        return 1
    fi

    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        print_error "Count must be a number"
        return 1
    fi

    check_wordpress

    print_header "Generating $count products for category: $category"

    case "$category" in
        elektronik)
            create_products_from_templates "$count" \
                "Smartphone Pro Max:899.99:Neuestes Smartphone mit 256GB Speicher und Triple-Kamera:Flagship Smartphone:20:0.2" \
                "Tablet 11 Zoll:549.99:Leistungsstarkes Tablet für Arbeit und Entertainment:Premium Tablet:15:0.5" \
                "Wireless Earbuds:149.99:True Wireless Kopfhörer mit ANC:Premium Earbuds:30:0.1" \
                "Smart TV 55 Zoll:799.99:4K Smart TV mit HDR und Android TV:55 Zoll Smart TV:8:15.5" \
                "Laptop Gaming:1299.99:High-Performance Gaming Laptop:Gaming Laptop:5:2.5" \
                "Powerbank 20000mAh:39.99:Portable Powerbank mit Quick Charge:Schnelllade Powerbank:50:0.4" \
                "Smart Watch Sport:299.99:Fitness Smartwatch mit GPS:Sport Smartwatch:25:0.08" \
                "Bluetooth Lautsprecher:79.99:Wasserdichter Bluetooth Speaker:Portabler Speaker:40:0.6"
            ;;
        kleidung)
            create_products_from_templates "$count" \
                "Designer Jeans:89.99:Premium Denim Jeans in Slim Fit:Designer Denim Jeans:30:0.6" \
                "Winterjacke Outdoor:199.99:Wasserdichte Winterjacke mit Daune:Warme Winterjacke:20:1.2" \
                "Sneaker Limited Edition:159.99:Limitierte Sneaker-Edition:Exklusive Sneaker:15:0.8" \
                "Pullover Wolle:79.99:Kuscheliger Wollpullover:Warmer Wollpullover:25:0.4" \
                "Sommerkleid Elegant:69.99:Elegantes Sommerkleid für besondere Anlässe:Elegantes Kleid:18:0.3" \
                "Sportshorts Performance:34.99:Atmungsaktive Shorts für Sport:Performance Shorts:40:0.2" \
                "Wintermütze Strick:24.99:Warme Strickmütze für den Winter:Warme Mütze:50:0.1" \
                "Business Hemd:49.99:Klassisches Business-Hemd:Business Hemd:35:0.25"
            ;;
        haushalt)
            create_products_from_templates "$count" \
                "Kaffeemaschine Deluxe:299.99:Vollautomatische Kaffeemaschine mit Milchaufschäumer:Premium Kaffeemaschine:12:8.5" \
                "Staubsauger Roboter:399.99:Intelligenter Saugroboter mit App-Steuerung:Smart Staubsauger:8:3.2" \
                "Luftreiniger HEPA:199.99:HEPA-Luftreiniger für reine Raumluft:HEPA Luftreiniger:15:4.1" \
                "Küchenwaage Digital:29.99:Präzise Digitalwaage für die Küche:Digitale Küchenwaage:30:1.2" \
                "Bettwäsche Set Baumwolle:59.99:Hochwertige Bettwäsche aus 100% Baumwolle:Baumwoll Bettwäsche:25:1.5" \
                "Wanduhr Design:79.99:Moderne Designer-Wanduhr:Designer Wanduhr:20:0.8" \
                "Pflanzenlampe LED:49.99:LED-Pflanzenlampe für Indoor-Gärtnern:LED Grow Light:18:0.6" \
                "Aromadiffuser:39.99:Ultraschall Aromadiffuser mit LED:Aroma Diffuser:35:0.4"
            ;;
        sport)
            create_products_from_templates "$count" \
                "Hantelset 20kg:129.99:Verstellbares Hantelset für Heimtraining:Heimtraining Hanteln:10:20.5" \
                "Yogamatte Premium:59.99:Rutschfeste Premium Yogamatte:Premium Yoga Matte:25:1.8" \
                "Fußball Official:34.99:Offizieller Trainingsball:Training Fußball:40:0.4" \
                "Laufschuhe Performance:149.99:Hochwertige Laufschuhe für Marathon:Marathon Laufschuhe:20:0.3" \
                "Fitness Tracker Pro:249.99:Profi Fitness-Tracker mit GPS:GPS Fitness Tracker:15:0.06" \
                "Protein Shake 1kg:39.99:Hochwertiges Whey Protein:Whey Protein Pulver:50:1.0" \
                "Springseil Speed:19.99:Schnelles Springseil für Cardio:Speed Rope:60:0.2" \
                "Widerstandsbänder Set:24.99:Vielseitiges Resistance Band Set:Resistance Bands:45:0.5"
            ;;
        *)
            print_error "Unknown category: $category"
            echo "Available categories: elektronik, kleidung, haushalt, sport"
            return 1
            ;;
    esac

    show_product_summary
}

show_product_summary() {
    check_wordpress

    print_header "Current Product Summary"

    local total
    total=$(run_wp wc product list --format=count 2>/dev/null || echo "0")
    echo "📦 Total products: $total"

    print_status "Recent products:"
    if ! run_wp wc product list \
        --format=table \
        --fields=id,name,regular_price,stock_quantity \
        --orderby=date \
        --order=desc \
        --per_page=5 2>/dev/null | sed 's/^/   /'; then
        echo "   No products found"
    fi
}

bulk_update() {
    local action="${1:-}"
    local value="${2:-}"

    if [[ -z "$action" ]]; then
        print_error "Bulk update action required"
        echo "Available actions: sale, stock"
        return 1
    fi

    check_wordpress

    print_header "Bulk Update: $action"

    case "$action" in
        sale)
            if [[ -z "$value" ]]; then
                print_error "Sale percentage required"
                echo "Usage: ./content-automation.sh bulk-update sale 20"
                return 1
            fi

            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_error "Sale percentage must be numeric"
                return 1
            fi

            print_status "Applying $value% sale to all products"

            local product_ids
            product_ids=$(run_wp wc product list --format=csv --fields=id 2>/dev/null | tail -n +2)

            local count=0
            while IFS= read -r product_id; do
                if [[ -n "$product_id" ]]; then
                    local regular_price
                    regular_price=$(run_wp wc product get "$product_id" --field=regular_price 2>/dev/null || echo "0")

                    if [[ "$regular_price" != "0" ]]; then
                        local sale_price
                        sale_price=$(echo "$regular_price * (100 - $value) / 100" | bc -l | xargs printf "%.2f")
                        run_wp wc product update "$product_id" --sale_price="$sale_price" >/dev/null 2>&1
                        count=$((count + 1))
                    fi
                fi
            done <<< "$product_ids"

            print_success "Applied $value% sale to $count products"
            ;;
        stock)
            if [[ -z "$value" ]]; then
                print_error "Stock quantity required"
                echo "Usage: ./content-automation.sh bulk-update stock 25"
                return 1
            fi

            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_error "Stock quantity must be numeric"
                return 1
            fi

            print_status "Setting stock quantity to $value for all products"

            local product_ids
            product_ids=$(run_wp wc product list --format=csv --fields=id 2>/dev/null | tail -n +2)

            local count=0
            while IFS= read -r product_id; do
                if [[ -n "$product_id" ]]; then
                    run_wp wc product update "$product_id" \
                        --stock_quantity="$value" \
                        --manage_stock=true >/dev/null 2>&1
                    count=$((count + 1))
                fi
            done <<< "$product_ids"

            print_success "Updated stock quantity for $count products"
            ;;
        *)
            print_error "Unknown bulk update action: $action"
            echo "Available actions: sale, stock"
            return 1
            ;;
    esac
}

clear_products() {
    local confirm="${1:-}"

    if [[ "$confirm" != "yes" ]]; then
        print_warning "This will delete ALL products"
        echo "Add 'yes' to confirm: ./content-automation.sh clear-products yes"
        return 1
    fi

    check_wordpress

    print_header "Clearing All Products"
    print_warning "Deleting all products..."

    local product_ids
    product_ids=$(run_wp wc product list --format=csv --fields=id 2>/dev/null | tail -n +2)

    local count=0
    while IFS= read -r product_id; do
        if [[ -n "$product_id" ]]; then
            run_wp wc product delete "$product_id" --force=true >/dev/null 2>&1
            count=$((count + 1))
        fi
    done <<< "$product_ids"

    print_success "Deleted $count products"
}

show_help() {
    print_header "Content Automation for WooCommerce"
    echo ""
    echo "Usage: ./content-automation.sh [command] [options]"
    echo ""
    echo "CSV Operations:"
    echo "  generate-sample      - Create sample product CSV"
    echo "  import-csv <file>    - Import products from CSV"
    echo "  export-csv [file]    - Export products to CSV"
    echo ""
    echo "Product Generation:"
    echo "  generate <category> [count] - Generate products by category"
    echo "                                 Categories: elektronik, kleidung, haushalt, sport"
    echo ""
    echo "Bulk Operations:"
    echo "  bulk-update sale <percent>   - Apply sale percentage to all products"
    echo "  bulk-update stock <quantity> - Set stock quantity for all products"
    echo "  clear-products yes           - Delete all products (requires confirmation)"
    echo ""
    echo "Information:"
    echo "  summary              - Show product summary"
    echo ""
    echo "Examples:"
    echo "  ./content-automation.sh generate-sample"
    echo "  ./content-automation.sh import-csv sample-data/sample-products.csv"
    echo "  ./content-automation.sh generate elektronik 8"
    echo "  ./content-automation.sh bulk-update sale 25"
    echo "  ./content-automation.sh export-csv my-products.csv"
    echo ""
    echo "Directories:"
    echo "  $IMPORT_DIR/  - CSV files for import"
    echo "  $EXPORT_DIR/  - Exported CSV files"
    echo "  $SAMPLES_DIR/ - Sample data files"
}

case "${1:-help}" in
    generate-sample)
        generate_sample_csv
        ;;
    import-csv)
        import_csv "${2:-}"
        ;;
    export-csv)
        export_csv "${2:-}"
        ;;
    generate)
        generate_products "${2:-}" "${3:-}"
        ;;
    bulk-update)
        bulk_update "${2:-}" "${3:-}"
        ;;
    clear-products)
        clear_products "${2:-}"
        ;;
    summary)
        show_product_summary
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: ${1:-}"
        echo
        show_help
        exit 1
        ;;
esac
